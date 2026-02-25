// Auto-start the WS-API server when Nuxt boots
import { startWsServer } from '../utils/ws-manager';

export default defineNitroPlugin(async () => {
  try {
    await startWsServer();
    console.log('[Plugin] WS-API auto-started');
  } catch (e: any) {
    console.error('[Plugin] Failed to auto-start WS-API:', e.message);
  }
});
