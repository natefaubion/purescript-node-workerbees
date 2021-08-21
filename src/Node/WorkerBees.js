var fs = require("fs");
var workerThreads = require("worker_threads");

exports.spawnImpl = function(left, right, worker, options, cb) {
  worker.resolve(function(err, res) {
    if (err) {
      return cb(left(err))();
    }
    var thread;
    var requirePath = res.filePath.replace(/\\/g, "\\\\");
    var jsEval = res.export
      ? 'require("' + requirePath + '").' + res.export + '.spawn()'
      : 'require("' + requirePath + '")';
    try {
      thread = new workerThreads.Worker(jsEval, {
        eval: true,
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
};

exports.makeImpl = function(ctor) {
  var originalFn = Error.prepareStackTrace;
  var worker, workerError, callerFilePath, callerLineNumber;

  Error.prepareStackTrace = function(err, stack) {
    return stack;
  };

  try {
    var stack = new Error().stack;

    do {
      var frame = stack.shift();
      callerFilePath = frame.getFileName();
      callerLineNumber = frame.getLineNumber();
    } while (callerFilePath === __filename);

    Error.prepareStackTrace = originalFn;

  } catch (e) {
    Error.prepareStackTrace = originalFn;
    throw new Error("Unable to define worker.");
  }

  function resolve(cb) {
    if (worker || workerError) {
      return cb(workerError, worker);
    }

    fs.readFile(callerFilePath, function(err, buff) {
      if (err) {
        workerError = err
        return cb(workerError);
      }

      var callerModuleLines = buff.toString('utf8').split('\n');
      var callerLine = callerModuleLines[callerLineNumber - 1];
      var workerName = callerLine.match(new RegExp("^var ([\\p{Ll}_][\\p{L}0-9_']*) = Node_WorkerBees\\.make", "u"));

      if (workerName) {
        var exportRegex = new RegExp("^\\s*" + workerName[1] + ":\\s*" + workerName[1]);
        for (var i = callerLineNumber; i < callerModuleLines.length; i++) {
          if (callerModuleLines[i] === "module.exports = {") {
            var exported = callerModuleLines.slice(i).some(function(line) {
              return exportRegex.test(line);
            });
            if (exported) {
              worker = {
                filePath: callerFilePath,
                export: workerName[1]
              };
              return cb(void 0, worker);
            }
          }
        }
      }

      workerError = new Error("Worker must be defined in a top-level, exported binding");
      cb(workerError);
    });
  }

  return {
    resolve: resolve,
    spawn: mainImpl(ctor)
  };
};

exports.unsafeMakeImpl = function(params) {
  return {
    resolve: function(cb) {
      cb(void 0, params);
    },
    spawn: function() {
      throw new Error("Cannot spawn unsafe worker directly.");
    }
  };
};

function mainImpl(ctor) {
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

exports.mainImpl = mainImpl;

exports.postImpl = function(value, worker) {
  worker.postMessage(value);
};

exports.terminateImpl = function(left, right, worker, cb) {
  worker.terminate()
    .then(function() {
      cb(right(void 0))();
    })
    .catch(function(err) {
      cb(left(err))();
    });
};

exports.threadId = function(worker) {
  return worker.threadId;
};
