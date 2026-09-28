import assert from 'node:assert/strict'
import { uploadFicha, fichaDownloadLink } from '../src/routes/core.js'

const nativeFetch = globalThis.fetch
const businessId = '11111111-1111-4111-8111-111111111111'
const calls = []
let platform = true
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(input)
  calls.push({ path: url.pathname, init })
  const json = (body, status = 200) => new Response(JSON.stringify(body), {
    status, headers: { 'content-type': 'application/json' },
  })
  if (url.pathname === '/auth/v1/user') return json({ id: 'admin-id' })
  if (url.pathname === '/rest/v1/profiles') return json([{
    id: 'admin-id', business_id: businessId, role_code: 'ADMIN', city: 'Nuevo Laredo', is_active: true,
  }])
  if (url.pathname === '/rest/v1/rpc/is_platform_operator') return json(platform)
  if (url.pathname === '/rest/v1/business_ficha_versions' && url.searchParams.get('select') === 'version') return json([])
  if (url.pathname === `/storage/v1/object/fichas/${businessId}/1.pdf`) return json({ Key: `fichas/${businessId}/1.pdf` })
  if (url.pathname === '/rest/v1/rpc/create_ficha_version') return json({ id: 'ficha-id', version: 1 })
  if (url.pathname === '/rest/v1/business_ficha_versions') return json([{
    id: 'ficha-id', document_path: `${businessId}/1.pdf`, client_approved: true, tlc_approved: true,
  }])
  if (url.pathname === `/storage/v1/object/sign/fichas/${businessId}/1.pdf`) return json({ signedURL: `/storage/v1/object/sign/fichas/${businessId}/1.pdf?token=temporary` })
  throw new Error(`Unexpected request: ${url.pathname}`)
}

const env = { SUPABASE_URL: 'https://staging.example', SUPABASE_ANON_KEY: 'public-test', SUPABASE_SECRET_KEY: 'secret-test' }
function uploadRequest() {
  const form = new FormData()
  form.append('business_id', businessId)
  form.append('pdf', new File(['%PDF-1.4\n%%EOF'], 'ficha.pdf', { type: 'application/pdf' }))
  return new Request('https://worker.example/api/platform/fichas', {
    method: 'POST', headers: { authorization: 'Bearer test-token' }, body: form,
  })
}

try {
  const uploaded = await uploadFicha(uploadRequest(), env)
  assert.equal((await uploaded.json()).data.version, 1)
  const objectCall = calls.find(call => call.path === `/storage/v1/object/fichas/${businessId}/1.pdf`)
  assert.equal(objectCall.init.headers.authorization, 'Bearer secret-test')
  assert.equal(objectCall.init.headers['x-upsert'], 'false')

  const downloaded = await fichaDownloadLink(new Request('https://worker.example/api/fichas/download?ficha_id=ficha-id', {
    headers: { authorization: 'Bearer test-token' },
  }), env)
  assert.match((await downloaded.json()).data.url, /token=temporary/)

  platform = false
  calls.length = 0
  await assert.rejects(uploadFicha(uploadRequest(), env), /Solo Tras La Chuleta/)
  assert.equal(calls.some(call => call.path.startsWith('/storage/')), false)
  process.stdout.write('PASS private Ficha PDF upload/download and platform guard\n')
} finally { globalThis.fetch = nativeFetch }
