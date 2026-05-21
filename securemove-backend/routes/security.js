const express = require('express');

const authenticateToken = require('../middleware/authenticateToken');
const { listAuditLogsForViewer } = require('../services/security_audit');

const router = express.Router();

router.get('/audit-logs', authenticateToken, async (req, res) => {
  try {
    const rows = await listAuditLogsForViewer({
      viewer: req.user,
      limit: req.query.limit,
      scope: req.query.scope,
    });

    return res.json({ logs: rows });
  } catch (err) {
    console.error('Audit log fetch error:', err.message);
    return res.status(500).json({ error: 'Unable to fetch audit logs' });
  }
});

module.exports = router;
