// services/roleService.js

const ROLES = {
  SYSTEM_ADMIN: 1,
  COMPANY_ADMIN: 2,
  INSPECTOR: 3,
  PASSENGER: 4
};

function hasRole(userRoleId, requiredRoleId) {
  return userRoleId === requiredRoleId;
}

function isInspector(userRoleId) {
  return userRoleId === ROLES.INSPECTOR;
}

function isCompanyAdmin(userRoleId) {
  return userRoleId === ROLES.COMPANY_ADMIN;
}

function isPassenger(userRoleId) {
  return userRoleId === ROLES.PASSENGER;
}

module.exports = {
  ROLES,
  hasRole,
  isInspector,
  isCompanyAdmin,
  isPassenger
};
