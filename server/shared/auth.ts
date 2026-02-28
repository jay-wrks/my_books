// ============================================================================
// JWT + Password helpers — shared by admin APIs and WS server
// ============================================================================

import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';

const SECRET = () => process.env.JWT_SECRET || 'dev-secret-change-in-production';

export interface TokenPayload {
  userId: string;
  email: string;
  role: 'user' | 'admin' | 'developer';
  /** @deprecated kept for backward compat with old tokens */
  isAdmin?: boolean;
}

export const hashPwd = (p: string) => bcrypt.hashSync(p, 10);
export const checkPwd = (p: string, h: string) => bcrypt.compareSync(p, h);
export const signJwt = (p: TokenPayload) => jwt.sign(p, SECRET(), { expiresIn: '30d' });

export function verifyJwt(token: string): TokenPayload | null {
  try {
    return jwt.verify(token, SECRET()) as TokenPayload;
  } catch {
    return null;
  }
}
