import fs from "fs";
import workerThreads from "worker_threads";
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)

export function spawnImpl(left, right, worker, options, cb) {
  worker.resolve(function(err, res) {
    if (err) {
      return cb(left(err))();
    }
    var thread;
    var requirePath = res.filePath.replace(/\\/g, "\\\\");
    var jsEval = res.export
      ? [
          'var worker = require("' + requirePath + '").' + res.export + ';',
          'worker.spawn ? worker.spawn() : worker();'
        ].join('\n')
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
}

export function makeImpl(ctor) {
  var originalFn = Error.prepareStackTrace;
  var worker, workerError, callerFilePath, callerLineNumber;

  Error.prepareStackTrace = function(err, stack) {
    return stack;
  };

  try {
    var stack = new Error().stack;

    do {
      var frame = stack.shift();
      callerFilePath = frame.getFileName().replace("file://", "");
      callerLineNumber = frame.getLineNumber();
    } while (callerFilePath === __filename);

    Error.prepareStackTrace = originalFn;
  } catch (e) {
    Error.prepareStackTrace = originalFn;
    throw new Error("Unable to define worker:", e);
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
      var workerName = callerLine.replace("/* #__PURE__ */ ", "").match(new RegExp("^var ([\\p{Ll}_][\\p{L}0-9_']*) = Node_WorkerBees\\.make", "u"));

      if (workerName) {
        var exportRegex = new RegExp("^\\s*" + workerName[1]);
        for (var i = callerLineNumber; i < callerModuleLines.length; i++) {
          if (callerModuleLines[i] === "export {") {
            var exported = callerModuleLines.slice(i).some(function(line) {
              console.log(line)
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

export {mainImpl};

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
  return worker.threadId;
}
