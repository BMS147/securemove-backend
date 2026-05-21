const jwt = require('jsonwebtoken');

const ROLE_BY_ID = {
  1: 'passenger',
  2: 'company_admin',
  3: 'super_admin',
  4: 'driver',
  5: 'conductor',
};

function normalizeUser(decoded) {
  const role = decoded.role || ROLE_BY_ID[decoded.role_id] || decoded.role_id;
  const companyId = decoded.companyId ?? decoded.company_id ?? null;
  return {
    ...decoded,
    role,
    companyId,
    company_id: companyId,
  };
}

function checkRole(...allowedRoles) {
  return (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      return res.status(401).json({ error: 'No token' });
    }

    try {
      const decoded = normalizeUser(jwt.verify(token, process.env.JWT_SECRET || 'supersecretkey'));
      if (!allowedRoles.includes(decoded.role)) {
        return res.status(403).json({ error: 'Access denied' });
      }

      req.user = decoded;
      return next();
    } catch {
      return res.status(401).json({ error: 'Invalid token' });
    }
  };
}

module.exports = checkRole;
module.exports.ROLE_BY_ID = ROLE_BY_ID;
module.exports.normalizeUser = normalizeUser;
