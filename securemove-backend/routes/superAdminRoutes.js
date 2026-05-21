const express = require('express');
const checkRole = require('../middleware/checkRole');
const controller = require('../controllers/superAdminController');

const router = express.Router();
const superAdminOnly = checkRole('super_admin');

router.get('/dashboard', superAdminOnly, controller.dashboard);
router.get('/companies', superAdminOnly, controller.companies);
router.put('/companies/:id/approve', superAdminOnly, controller.approveCompany);
router.delete('/companies/:id', superAdminOnly, controller.deleteCompany);
router.get('/users', superAdminOnly, controller.users);
router.put('/users/:id/role', superAdminOnly, controller.updateUserRole);
router.delete('/users/:id', superAdminOnly, controller.deleteUser);
router.get('/transactions', superAdminOnly, controller.transactions);
router.get('/security-logs', superAdminOnly, controller.securityLogs);
router.get('/reports', superAdminOnly, controller.reports);
router.get('/analytics', superAdminOnly, controller.analytics);

module.exports = router;
