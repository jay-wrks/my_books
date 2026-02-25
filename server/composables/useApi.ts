// Composable: admin API calls with auth
export function useApi() {
  const token = useCookie('admin_token');

  async function api<T = any>(path: string, opts: any = {}): Promise<T> {
    const headers: any = { ...opts.headers };
    if (token.value) headers['Authorization'] = `Bearer ${token.value}`;
    const res = await $fetch<T>(`/api/admin/${path}`, {
      ...opts,
      headers,
    });
    return res;
  }

  return { api, token };
}
