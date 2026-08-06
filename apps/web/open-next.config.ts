import { defineCloudflareConfig } from '@opennextjs/cloudflare';

// Next.js reaches Cloudflare through this adapter rather than natively. That
// cost was weighed and accepted in ADR-0008 Amendment 1 rather than missed:
// Vercel is smoother, and splitting Kafoo's deploy story across two platforms was
// judged the larger price.
export default defineCloudflareConfig();
