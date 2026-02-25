// ---------------------------------------------------------------------------
// WS-API lifecycle manager — lazy-loads ws-api/index.ts at runtime
// to avoid Rollup/Nitro bundling issues with top-level side effects.
// ---------------------------------------------------------------------------

let wsModule: any = null;

async function getWsModule() {
  if (!wsModule) {
    // Dynamic import bypasses Rollup's static analysis
    wsModule = await import('../../ws-api/index');
  }
  return wsModule;
}

export async function startWsServer(): Promise<void> {
  const mod = await getWsModule();
  await mod.startServer();
}

export async function stopWsServer(): Promise<void> {
  const mod = await getWsModule();
  await mod.stopServer();
}

export async function isWsServerRunning(): Promise<boolean> {
  const mod = await getWsModule();
  return mod.isServerRunning();
}

export async function getWsStats() {
  const mod = await getWsModule();
  return mod.getWsStats();
}

export async function pushToWsUser(userId: string, event: string, data: any = {}) {
  const mod = await getWsModule();
  mod.pushToUser(userId, event, data);
}
