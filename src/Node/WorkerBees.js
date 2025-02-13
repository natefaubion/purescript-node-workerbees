import workerThreads from "worker_threads";

export function spawnImpl(left, right, worker, options, cb) {
  worker.resolve(function(err, res) {
    if (err) {
      return cb(left(err))();
    }
    var thread;
    // Must be either an absolute path or a relative path (i.e. relative to the
    // current working directory) starting with ./ or ../, if a filepath.
    // https://nodejs.org/api/worker_threads.html#new-workerfilename-options
    var importPath = res.filePath;
    try {
      thread = new workerThreads.Worker(importPath, {
        workerData: options.workerData
      });
      thread.on('message', function(value) {
        return options.onMessage(value)();
      });
      thread.on('error', function(err) {
        return options.onError(err)();
      });
      thread.on('exit', function(code) {
        return options.onExit(code)();
      });
      thread.on('online', function() {
        cb(right(thread))();
      });
    } catch(e) {
      cb(left(e))();
    }
  });
}

export function unsafeMakeImpl(params) {
  return {
    resolve: function(cb) {
      cb(void 0, params);
    },
    spawn: function() {
      throw new Error("Cannot spawn unsafe worker directly.");
    }
  };
}

export function mainImpl(ctor) {
  return function() {
    if (workerThreads.isMainThread) {
      throw new Error("Worker running on main thread.");
    }
    ctor({
      exit: function() {
        process.exit();
      },
      receive: function(cb) {
        return function() {
          workerThreads.parentPort.on('message', function(value) {
            cb(value)();
          });
        };
      },
      reply: function(value) {
        return function() {
          workerThreads.parentPort.postMessage(value);
        };
      },
      threadId: workerThreads.threadId,
      workerData: workerThreads.workerData
    })();
  };
}

export function postImpl(value, worker) {
  worker.postMessage(value);
}

export function terminateImpl(left, right, worker, cb) {
  worker.terminate()
    .then(function() {
      cb(right(void 0))();
    })
    .catch(function(err) {
      cb(left(err))();
    });
}

export function threadId(worker) {
  return function() {
    return worker.threadId;
  };
}
