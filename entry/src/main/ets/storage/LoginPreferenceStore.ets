import { appPreferences } from './AppPreferences'

const REMEMBER_LOGIN_KEY = 'remember_login'
const LAST_LOGIN_MODE_KEY = 'last_login_mode'
const LAST_USERNAME_KEY = 'last_username_account'
const LAST_CONTACT_KEY = 'last_contact_account'

export interface LoginPreferenceSnapshot {
  remember: boolean
  loginMode: string
  usernameAccount: string
  contactAccount: string
}

export function normalizeLoginMode(value: string): string {
  return value === 'contact' ? 'contact' : 'username'
}

class LoginPreferenceStore {
  async load(): Promise<LoginPreferenceSnapshot> {
    const remember = await appPreferences.getString(REMEMBER_LOGIN_KEY) === 'true'
    if (!remember) {
      return {
        remember: false,
        loginMode: 'username',
        usernameAccount: '',
        contactAccount: ''
      }
    }
    return {
      remember: true,
      loginMode: normalizeLoginMode(await appPreferences.getString(LAST_LOGIN_MODE_KEY)),
      usernameAccount: await appPreferences.getString(LAST_USERNAME_KEY),
      contactAccount: await appPreferences.getString(LAST_CONTACT_KEY)
    }
  }

  async save(loginMode: string, account: string, remember: boolean): Promise<void> {
    if (!remember) {
      await appPreferences.remove(REMEMBER_LOGIN_KEY)
      await appPreferences.remove(LAST_LOGIN_MODE_KEY)
      await appPreferences.remove(LAST_USERNAME_KEY)
      await appPreferences.remove(LAST_CONTACT_KEY)
      return
    }

    const normalizedMode = normalizeLoginMode(loginMode)
    await appPreferences.putString(REMEMBER_LOGIN_KEY, 'true')
    await appPreferences.putString(LAST_LOGIN_MODE_KEY, normalizedMode)
    await appPreferences.putString(
      normalizedMode === 'contact' ? LAST_CONTACT_KEY : LAST_USERNAME_KEY,
      account.trim()
    )
  }
}

export const loginPreferenceStore = new LoginPreferenceStore()
