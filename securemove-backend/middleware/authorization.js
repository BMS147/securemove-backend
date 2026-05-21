function isSystemAdmin(user) {
  return user?.role_id === 3;
}

function isCompanyAdmin(user) {
  return user?.role_id === 2;
}

function isDriver(user) {
  return user?.role_id === 4;
}

function canManageCompany(user, companyId) {
  if (isSystemAdmin(user)) {
    return true;
  }

  if (!isCompanyAdmin(user)) {
    return false;
  }

  return Number(user.company_id) === Number(companyId);
}

function requireManagementUser(req, res, next) {
  if (isSystemAdmin(req.user) || isCompanyAdmin(req.user)) {
    return next();
  }

  return res.status(403).json({ error: 'Management access is required' });
}

module.exports = {
  canManageCompany,
  isCompanyAdmin,
  isDriver,
  isSystemAdmin,
  requireManagementUser,
};
