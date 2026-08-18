import huks from '@ohos.security.huks'
import util from '@ohos.util'
import { appPreferences } from './AppPreferences'

const KEY_ALIAS = 'wifi_manager_session_key_v1'
const ENCRYPTED_SESSION_KEY = 'encrypted_session_v1'
const FORMAT_VERSION = 'v1'

function keyProperties(): huks.HuksParam[] {
  return [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    {
      tag: huks.HuksTag.HUKS_TAG_PURPOSE,
      value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
    },
    { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
  ]
}

function operationProperties(purpose: huks.HuksKeyPurpose, nonce: Uint8Array): huks.HuksParam[] {
  return [
    { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
    { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: purpose },
    { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
    { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE },
    { tag: huks.HuksTag.HUKS_TAG_NONCE, value: nonce },
    { tag: huks.HuksTag.HUKS_TAG_AE_TAG_LEN, value: 128 }
  ]
}

class SecureStore {
  private readonly base64 = new util.Base64Helper()
  private readonly encoder = new util.TextEncoder('utf-8')
  private readonly decoder = new util.TextDecoder('utf-8')

  private async ensureKey(): Promise<void> {
    const exists = await huks.isKeyItemExist(KEY_ALIAS, {})
    if (!exists) {
      await huks.generateKeyItem(KEY_ALIAS, { properties: keyProperties() })
    }
  }

  private async transform(
    input: Uint8Array,
    purpose: huks.HuksKeyPurpose,
    nonce: Uint8Array
  ): Promise<Uint8Array> {
    await this.ensureKey()
    const session = await huks.initSession(KEY_ALIAS, {
      properties: operationProperties(purpose, nonce)
    })
    const result = await huks.finishSession(session.handle, { inData: input })
    if (result.outData === undefined) {
      throw new Error('安全存储未返回有效数据')
    }
    return result.outData
  }

  async writeSession(value: string): Promise<void> {
    const nonce = util.generateRandomBinaryUUID().slice(0, 12)
    const encrypted = await this.transform(
      this.encoder.encodeInto(value),
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT,
      nonce
    )
    const payload =
      `${FORMAT_VERSION}:${this.base64.encodeToStringSync(nonce)}:${this.base64.encodeToStringSync(encrypted)}`
    await appPreferences.putString(ENCRYPTED_SESSION_KEY, payload)
  }

  async readSession(): Promise<string> {
    const payload = await appPreferences.getString(ENCRYPTED_SESSION_KEY)
    if (payload.length === 0) {
      return ''
    }
    const parts = payload.split(':')
    if (parts.length !== 3 || parts[0] !== FORMAT_VERSION) {
      throw new Error('本地会话格式无效')
    }
    const nonce = this.base64.decodeSync(parts[1])
    const encrypted = this.base64.decodeSync(parts[2])
    const decrypted = await this.transform(
      encrypted,
      huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT,
      nonce
    )
    return this.decoder.decodeToString(decrypted)
  }

  async clearSession(): Promise<void> {
    await appPreferences.remove(ENCRYPTED_SESSION_KEY)
  }
}

export const secureStore = new SecureStore()
