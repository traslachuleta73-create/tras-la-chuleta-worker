import assert from 'node:assert/strict'
import { createBusinessUser } from '../src/routes/core.js'

const nativeFetch = globalThis.fetch
const calls = []
let role = 'ADMIN'
let attachFails = false
globalThis.fetch = async (input, init = {}) => {
  const path = new URL(input).pathname
  calls.push({ path, init })
  const json = (value, status = 200) => new Response(JSON.stringify(value), {
    status, headers: { 'content-type': 'application/json' },
  })
  if (path === '/auth/v1/user') return json({ id: 'user-admin' })
  if (path === '/rest/v1/profiles') return json([{
    id: 'user-admin', business_id: 'business-A', role_code: role, city: 'Nuevo Laredo', is_active: true,
  }])
  if (path === '/auth/v1/admin/users' && init.method === 'POST') return json({ id: 'new-user' })
  if (path === '/rest/v1/rpc/attach_business_user') {
    return attachFails ? json({ message: 'PROFILE_REJECTED' }, 400) : json({ id: 'new-user', business_id: 'business-A' })
  }
  if (path === '/auth/v1/admin/users/new-user' && init.method === 'DELETE') return json({})
  throw new Error(`Unexpected request: ${path}`)
}

const env = { SUPABASE_URL: 'https://staging.example', SUPABASE_ANON_KEY: 'public-test', SUPABASE_SECRET_KEY: 'secret-test' }
function request() {
  return new Request('https://worker.example/api/admin/users/create', {
    method: 'POST', headers: { authorization: 'Bearer test-token', 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'cocina@prueba.mx', password: 'temporary-password-123',
      role_code: 'COCINA', display_name: 'Cocina', city: 'Nuevo Laredo' }),
  })
}

try {
  const response = await createBusinessUser(request(), env)
  assert.equal((await response.json()).data.business_id, 'business-A')
  const attached = calls.find(call => call.path.endsWith('attach_business_user'))
  assert.equal(JSON.parse(attached.init.body).p_role_code, 'COCINA')
  assert.equal(attached.init.headers.Authorization, 'Bearer test-token')

  calls.length = 0
  role = 'CAJA'
  await assert.rejects(createBusinessUser(request(), env), /Operación no autorizada/)
  assert.equal(calls.some(call => call.path === '/auth/v1/admin/users'), false)

  calls.length = 0
  role = 'ADMIN'
  attachFails = true
  await assert.rejects(createBusinessUser(request(), env), /PROFILE_REJECTED/)
  assert.equal(calls.some(call => call.path === '/auth/v1/admin/users/new-user' && call.init.method === 'DELETE'), true)
  process.stdout.write('PASS admin provisioning, role guard and cleanup\n')
} finally {
  globalThis.fetch = nativeFetch
}
