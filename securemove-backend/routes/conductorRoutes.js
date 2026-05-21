const express = require('express');
const checkRole = require('../middleware/checkRole');
const controller = require('../controllers/conductorController');

const router = express.Router();
const conductorOnly = checkRole('conductor');

router.get('/me', conductorOnly, controller.currentConductor);
router.get('/trip', conductorOnly, controller.trip);
router.post('/scan', conductorOnly, controller.scan);
router.put('/trip/status', conductorOnly, controller.updateTripStatus);

module.exports = router;
