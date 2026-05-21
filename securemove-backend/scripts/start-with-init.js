const { spawn } = require('child_process');

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: 'inherit',
      shell: true,
    });

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }

      reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
    });

    child.on('error', reject);
  });
}

async function start() {
  try {
    await run('node', ['scripts/init-db.js']);
    await run('node', ['server.js']);
  } catch (error) {
    console.error('Startup failed:', error.message);
    process.exit(1);
  }
}

start();
