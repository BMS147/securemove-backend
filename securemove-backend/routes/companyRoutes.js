const express = require('express');
const checkRole = require('../middleware/checkRole');
const controller = require('../controllers/companyController');

const router = express.Router();
const companyOnly = checkRole('company_admin');

router.get('/dashboard', companyOnly, controller.dashboard);
router.get('/buses', companyOnly, controller.listBuses);
router.post('/buses', companyOnly, controller.createBus);
router.put('/buses/:id', companyOnly, controller.updateBus);
router.delete('/buses/:id', companyOnly, controller.deleteBus);

router.get('/routes', companyOnly, controller.listRoutes);
router.post('/routes', companyOnly, controller.createRoute);
router.put('/routes/:id', companyOnly, controller.updateRoute);
router.delete('/routes/:id', companyOnly, controller.deleteRoute);

router.get('/schedules', companyOnly, controller.listSchedules);
router.post('/schedules', companyOnly, controller.createSchedule);
router.put('/schedules/:id', companyOnly, controller.updateSchedule);
router.delete('/schedules/:id', companyOnly, controller.deleteSchedule);

router.get('/staff', companyOnly, controller.listStaff);
router.post('/staff', companyOnly, controller.createStaff);
router.delete('/staff/:id', companyOnly, controller.deleteStaff);

router.get('/bookings', companyOnly, controller.bookings);

module.exports = router;
