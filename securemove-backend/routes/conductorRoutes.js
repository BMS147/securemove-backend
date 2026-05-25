const express = require('express');
const checkRole = require('../middleware/checkRole');
const controller = require('../controllers/conductorController');

const router = express.Router();
const conductorOnly = checkRole('conductor');

router.get('/me', conductorOnly, controller.currentConductor);
router.get('/trip', conductorOnly, controller.trip);
router.get('/stats', conductorOnly, controller.stats);
router.get('/session-stats', conductorOnly, controller.stats);
router.post('/scan', conductorOnly, controller.scan);
router.post('/report-duplicate', conductorOnly, controller.reportDuplicate);
router.put('/trip/status', conductorOnly, controller.updateTripStatus);

module.exports = router;
