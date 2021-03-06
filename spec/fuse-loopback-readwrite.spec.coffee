[ fs, fuse, path, child_process, loopbackfs, domain, microtime, coffeeline ] = [ 
  (require "fs-extra"),(require "fuse-bindings"),(require "path"),(require "child_process"),
  (require "../fuse-loopback-readwrite.coffee"),(require "domain"),(require "microtime-nodejs"),
  (require "coffee-line")
]
####################################################################################################
####################################################################################################
describe "Fuse-bindings loopback read-write filesystem implementation", ->
  time = {}
  datadir = if process.env.DATADIR then process.env.DATADIR else "data"
  testname = path.basename(path.basename(__filename,".coffee"),".spec")
  looproot = "#{datadir}/#{testname}-looproot"
  mountpoint = "#{datadir}/#{testname}-mountpoint"
  expectations =
    "all expectations are expected to be true"                                : true
    "init exceptions are not catchable"                                       : undefined
    "init is called prior to all other functions"                             : undefined
    "init always accept only 1 argument"                                      : undefined
    "init is called only 1 time per each mount"                               : undefined
    "init would NOT generate a FUSE error if pass to `cb` anything but 0"     : undefined
    "getattr `path` argument always starts with a slash"                      : undefined
    "readdir always accepts only 2 arguments"                                 : undefined
    "readdir is not called when entry doesn't exists"                         : undefined
    "readdir `path` argument always starts with a slash"                      : undefined
    "readdir is always preceded with gettattr call"                           : undefined
    "readdir could be called on nonexistant entries under some circumstances" : undefined
    "readdir returns weird stuff to `fs.readdir` when called on nonexistant"  : undefined
    "readdir returns empty array if entries_list is undefined"                : undefined
    "readdir returns empty array if entries_list is null"                     : undefined
    "fuse implementation functions are not integrated by the `this` context"  : undefined
  callhistory = []
  test_counter = 0
  zones_counter = 0
  fs.emptyDirSync(looproot)
  fs.emptyDirSync(mountpoint)
  loopbackfs_instance = loopbackfs(root:looproot)
  loopbackfs_debug_instance = 

    init: (cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "init"
        env: { cb: cb }
        name: "fuse call"
        this: @
        time: microtime.now()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.init(cb)

    readdir: (path, cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "readdir"
        env: { path: path, cb: cb }
        name: "fuse call"
        this: @
        time: microtime.now()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.readdir path, (err, files) ->
          callhistory.push(
            fn: "readdir"
            env: { path: path, cb: cb, err: err, files: files }
            name: "fuse result"
            this: @
            time: microtime.now()
            zone: zone
            args: arguments
            testnum: test_counter
          )
          cb(err,files)

    getattr: (path, cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "getattr"
        env: { path: path, cb: cb }
        name: "fuse call"
        this: @
        time: microtime.now()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.getattr path, (err, result) ->
          callhistory.push(
            fn: "getattr"
            env: { path: path, cb: cb, err: err, result: result }
            name: "fuse result"
            this: @
            time: microtime.now()
            zone: zone
            args: arguments
            testnum: test_counter
          )
          cb(err,result)

  # Copy undeclared functions to the debug instance.
  for key, val of loopbackfs_instance
    unless loopbackfs_debug_instance[key]?
      loopbackfs_debug_instance[key] = val
  
  # Mount function with some tests attached to it.
  mount_loopbackfs_debug_instance = (done) ->
    fuse.mount mountpoint, loopbackfs_debug_instance, (err) ->
      expect(arguments.length).toBe(1)
      expect(err).toBe(undefined)
      setTimeout(done,100)

  # Umount function with some tests attached to it.
  umount_loopbackfs_debug_instance = (done) ->
    setTimeout(
      ->
        child_process.exec "fusermount -u #{mountpoint}", (err,stdout,stderr) ->
          expect(arguments.length).toBe(3)
          expect(err).toBe(null)
          expect(stdout).toBe("")
          expect(stderr).toBe("")
          child_process.exec "fusermount -u #{mountpoint}", (err,stdout,stderr) ->
            expect(arguments.length).toBe(3)
            expect(err instanceof Error).toBe(true)
            expect(stdout).toBe("")
            expect(stderr.indexOf("not found in /etc/mtab")).not.toBe(-1)
            done()
      100
    )

  # Some tests require custom debug instance, some require none. Thus this is used when necessary.
  default_mount_wrapper = (done,middleware) ->
    mount_loopbackfs_debug_instance ->
      middleware ->
        umount_loopbackfs_debug_instance(done)

  # Increase test counter to separate tests from each other
  beforeEach -> test_counter++

####################################################################################################
####################################################################################################
  it "mounts and unmounts", (done) -> default_mount_wrapper done, (done) ->

    done() # Everything for this test happens in `default_mount_wrapper`.

####################################################################################################
####################################################################################################
  it "performs readdir without unexpected errors", (done) -> default_mount_wrapper done, (done) ->

    fs.mkdirSync(looproot + "/readdirtest")
    fs.mkdirSync(looproot + "/readdirtest/dir1")
    fs.mkdirSync(looproot + "/readdirtest/dir2")
    fs.mkdirSync(looproot + "/readdirtest/dir2/subdir")
    fs.readdir "#{mountpoint}/readdirtest", (err, files) ->
      expect(err).toBe(null)
      expect(files).toEqual(["dir1","dir2"])
      fs.readdir "#{mountpoint}/nonexistantdir", (err, files) ->
        expect(err.code).toBe("ENOENT")
        expect(files).toBe(undefined)
        fs.readdir "#{mountpoint}/readdirtest/dir2", (err, files) ->
          expect(err).toBe(null)
          expect(files).toEqual(['subdir'])
          time.before_reading_deleted_directory = microtime.now()
          fs.rmdirSync(looproot + "/readdirtest/dir1")
          fs.readdir "#{mountpoint}/readdirtest/dir1", (err, files) ->
            time.after_reading_deleted_directory = microtime.now()
            expect(err.code).toBe("ENOENT")
            expect(files).toBe(undefined)
            verify_expectations()

    verify_expectations = ->
      expect(
        callhistory.some (event) ->
          event.fn is "readdir" &&
          event.testnum is test_counter
      ).toBe(true)
      done()

####################################################################################################
####################################################################################################
  it "performs readdir on unexistent entry without unexpected errors", (done) ->

    dir2_was_deleted_right_between_getattr_and_readdir = false
    default_getattr = loopbackfs_debug_instance.getattr
    loopbackfs_debug_instance.getattr = (path, cb) ->
      zone = domain.create()
      zone.number = zones_counter++
      callhistory.push(
        fn: "getattr"
        env: { path: path, cb: cb }
        name: "fuse call"
        this: @
        time: microtime.now()
        zone: zone
        args: arguments
        testnum: test_counter
      )
      zone.run =>
        loopbackfs_instance.getattr path, (err, result) ->
          callhistory.push(
            fn: "getattr"
            env: { path: path, cb: cb, err: err, result: result }
            name: "fuse result"
            this: @
            time: microtime.now()
            zone: zone
            args: arguments
            testnum: test_counter
          )
          if path is "/readdirtest/dir2"
            fs.rmdirSync(rmpath = looproot + "/readdirtest/dir2/subdir")
            callhistory.push(
              fn: "rmdirSync"
              env: { rmpath: rmpath, path: path, cb: cb, err: err, result: result }
              name: "custom call"
              this: @
              time: microtime.now()
              zone: zone
              args: arguments
              testnum: test_counter
            )
            fs.rmdirSync(rmpath = looproot + "/readdirtest/dir2")
            callhistory.push(
              fn: "rmdirSync"
              env: { rmpath: rmpath, path: path, cb: cb, err: err, result: result }
              name: "custom call"
              this: @
              time: microtime.now()
              zone: zone
              args: arguments
              testnum: test_counter
            )
            dir2_was_deleted_right_between_getattr_and_readdir = true
          cb(err,result)

    mount_loopbackfs_debug_instance ->
      callhistory.push(
        fn: "Readdir `/readdirtest/dir2` is coming right after this message."
        env: {}
        name: "debug message"
        this: @
        time: microtime.now()
        args: arguments
        testnum: test_counter
      )
      fs.readdir "#{mountpoint}/readdirtest/dir2", (err, files) ->
        callhistory.push(
          fn: "Readdir `/readdirtest/dir2` results."
          env: { err: err, files: files }
          name: "debug message"
          this: @
          time: microtime.now()
          args: arguments
          testnum: test_counter
        )
        if err?.code is "ENOENT" and files is undefined
          expectations["readdir returns weird stuff to `fs.readdir` when called on nonexistant"] = false
        if err is null and "#{files}" is "#{[]}"
          expectations["readdir returns weird stuff to `fs.readdir` when called on nonexistant"] = true
        expect(expectations["readdir returns weird stuff to `fs.readdir` when called on nonexistant"]).not.toBe(undefined)
        umount_loopbackfs_debug_instance ->
          loopbackfs_debug_instance.getattr = default_getattr
          verify_expectations()

    verify_expectations = ->
      expect(dir2_was_deleted_right_between_getattr_and_readdir).toBe(true)
      done()

####################################################################################################
####################################################################################################
  it "performs custom init test without unexpected errors", (done) ->

    try

      custom_init_was_called = false
      default_init = loopbackfs_debug_instance.init
      loopbackfs_debug_instance.init = (cb) ->
        callhistory.push(
          fn: "init"
          env: { cb: cb }
          name: "fuse call"
          this: @
          time: microtime.now()
          args: arguments
          testnum: test_counter
        )
        loopbackfs_instance.init ->
          custom_init_was_called = true
          cb(fuse.ENODEV)

      mount_loopbackfs_debug_instance -> umount_loopbackfs_debug_instance ->
        loopbackfs_debug_instance.init = default_init
        verify_expectations()

      verify_expectations = ->
        expect(custom_init_was_called).toBe(true)
        expectations["init would NOT generate a FUSE error if pass to `cb` anything but 0"] = true
        done()

    catch err

      expectations["init would NOT generate a FUSE error if pass to `cb` anything but 0"] = false
      done()

####################################################################################################
####################################################################################################
  it "performs custom readdir test without unexpected errors", (done) ->

    default_readdir = loopbackfs_debug_instance.readdir
    loopbackfs_debug_instance.readdir = (path,cb) ->
      cb(0,undefined)

    readdir_result = undefined
    mount_loopbackfs_debug_instance -> 
      fs.readdir "#{mountpoint}/", (err, files) ->
        expect(err).toBe(null)
        expect(files).toEqual([])
        readdir_result = { err: err, files: files }
        umount_loopbackfs_debug_instance ->
          loopbackfs_debug_instance.readdir = default_readdir
          verify_expectations()

    verify_expectations = ->
      expectations["readdir returns empty array if entries_list is undefined"] = 
        readdir_result.err is null && "#{readdir_result.files}" is "#{[]}"
      done()

####################################################################################################
####################################################################################################
  it "performs another custom readdir test without unexpected errors", (done) ->

    default_readdir = loopbackfs_debug_instance.readdir
    loopbackfs_debug_instance.readdir = (path,cb) ->
      cb(0,null)

    readdir_result = undefined
    mount_loopbackfs_debug_instance -> 
      fs.readdir "#{mountpoint}/", (err, files) ->
        expect(err).toBe(null)
        expect(files).toEqual([])
        readdir_result = { err: err, files: files }
        umount_loopbackfs_debug_instance ->
          loopbackfs_debug_instance.readdir = default_readdir
          verify_expectations()

    verify_expectations = ->
      expectations["readdir returns empty array if entries_list is null"] = 
        readdir_result.err is null && "#{readdir_result.files}" is "#{[]}"
      done()

####################################################################################################
####################################################################################################
  it "performs test for `init exceptions are catchable` case", (done) ->

    process.on 'uncaughtException', uncaught_handler = (err) ->
      callhistory.push(
        env: { err: err }
        name: "uncaughtException"
        time: microtime.now()
        args: arguments
        testnum: test_counter
      )

    # For unknown reason it doesn't umounts easily and tells it's busy so we need to use a `z` flag.
    forced_lazy_umount = (done) -> 
      setTimeout(
        ->
          child_process.exec "fusermount -uz #{mountpoint}", (err,stdout,stderr) ->
            expect(arguments.length).toBe(3)
            expect(err).toBe(null)
            expect(stdout).toBe("")
            expect(stderr).toBe("")
            child_process.exec "fusermount -u #{mountpoint}", (err,stdout,stderr) ->
              expect(arguments.length).toBe(3)
              expect(err instanceof Error).toBe(true)
              expect(stdout).toBe("")
              expect(stderr.indexOf("not found in /etc/mtab")).not.toBe(-1)
              done()
        100
      )

    unexistant_looproot = "data/#{testname}-unexistant-looproot"
    test_instance = loopbackfs(root: unexistant_looproot)
    test_instance.init = (cb) ->
      callhistory.push(
        fn: "init"
        env: { cb: cb }
        name: "fuse call"
        this: @
        time: microtime.now()
        args: arguments
        testnum: test_counter
      )
      throw Error "Unexpected exception."

    try
      time.before_mounting_unexistant_looproot = microtime.now()
      fuse.mount mountpoint, test_instance, (err) ->
        expectations["init exceptions are not catchable"] = false if err?
        expect(arguments.length).toBe(1)
        expect(err).toBe(undefined)
    catch err
      expectations["init exceptions are not catchable"] = false

    setTimeout(
      -> 
        process.removeListener('uncaughtException', uncaught_handler)
        forced_lazy_umount(done)
        time.after_mounting_unexistant_looproot = microtime.now()
      3000
    )

####################################################################################################
####################################################################################################
  it "reads the file from looproot", (done) -> default_mount_wrapper done, (done) ->

    filename = "readable_file.txt"
    filedata = "Hello.\nI'm a readable file."
    fs.writeFileSync("#{looproot}/#{filename}", filedata)
    fs.readFile "#{mountpoint}/#{filename}", (err, data) ->
      expect(err).toBe(null)
      expect(data.toString()).toBe(filedata + "")
      done()

####################################################################################################
####################################################################################################
  it "writes the file to looproot", (done) -> default_mount_wrapper done, (done) ->

    filename = "writable_file.txt"
    filedata = "Hello.\nI'm a writable file."
    fs.writeFile "#{mountpoint}/#{filename}", filedata, (err) ->
      expect(err).toBe(null)
      expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe(filedata)
      done()

####################################################################################################
####################################################################################################
  it "can overwrite existing files", (done) -> default_mount_wrapper done, (done) ->

    filename = "overwritable_file.txt"
    filedata = "Hello.\nI'm an overwritable file."
    filedatanew = "Hello.\nI'm an OVERWRITED file."
    fs.writeFileSync("#{looproot}/#{filename}", filedata)
    fs.readFile "#{mountpoint}/#{filename}", (err, data) ->
      expect(err).toBe(null)
      expect(data.toString()).toBe(filedata + ""+ "")
      fs.writeFile "#{mountpoint}/#{filename}", filedatanew, (err) ->
        expect(err).toBe(null)
        expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe(filedatanew)
        done()

####################################################################################################
####################################################################################################
  it "can truncate files", (done) -> default_mount_wrapper done, (done) ->

    filename = "truncable_file.txt"
    filedata = "Hello.\nI'm a truncable file."
    fs.writeFileSync("#{looproot}/#{filename}", filedata)
    expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe(filedata)
    fs.truncate "#{mountpoint}/#{filename}", 4, (err) ->
      expect(err).toBe(null)
      expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe("Hell")
      done()

####################################################################################################
####################################################################################################
  it "can remove files", (done) -> default_mount_wrapper done, (done) ->

    filename = "newfile2236"
    fs.lstat "#{looproot}/#{filename}", (err, stats) ->
      expect(err.code).toBe("ENOENT")
      fs.writeFile "#{mountpoint}/#{filename}", "test", (err) ->
        expect(err).toBe(null)
        fs.lstat "#{looproot}/#{filename}", (err, stats) ->
          expect(err).toBe(null)
          expect(stats.mode).toBe(33204)
          fs.unlink "#{mountpoint}/#{filename}", (err) ->
            expect(err).toBe(null)
            fs.lstat "#{looproot}/#{filename}", (err, stats) ->
              expect(err.code).toBe("ENOENT")
              done()

####################################################################################################
####################################################################################################
  it "can chmod files", (done) -> default_mount_wrapper done, (done) ->

    filename = "chmod_file.txt"
    filedata = "Hello.\nI'm a chmod file."
    fs.writeFile "#{mountpoint}/#{filename}", filedata, (err) ->
      expect(err).toBe(null)
      expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe(filedata)
      fs.lstat "#{looproot}/#{filename}", (err, stats) ->
        expect(err).toBe(null)
        expect(stats.mode).toBe(33204)
        fs.chmod "#{mountpoint}/#{filename}", 0o777, (err) ->
          expect(err).toBe(null)
          fs.lstat "#{looproot}/#{filename}", (err, stats) ->
            expect(err).toBe(null)
            expect(stats.mode).toBe(33279)
            done()

####################################################################################################
####################################################################################################
  it "can move files", (done) -> default_mount_wrapper done, (done) ->

    filenamesrc = "move_src.txt"
    filenamedst = "move_dst.txt"
    filedata = "Hello.\nI'm a moved file."
    fs.writeFileSync("#{looproot}/#{filenamesrc}", filedata)
    fs.lstat "#{looproot}/#{filenamesrc}", (err, stats) ->
      expect(err).toBe(null)
      fs.lstat "#{looproot}/#{filenamedst}", (err, stats) ->
        expect(err.code).toBe("ENOENT")
        fs.rename "#{mountpoint}/#{filenamesrc}", "#{mountpoint}/#{filenamedst}", (err) ->
          expect(err).toBe(null)
          fs.lstat "#{looproot}/#{filenamesrc}", (err, stats) ->
            expect(err.code).toBe("ENOENT")
            fs.lstat "#{looproot}/#{filenamedst}", (err, stats) ->
              expect(err).toBe(null)
              done()

####################################################################################################
####################################################################################################
  it "can create and read symlinks", (done) -> default_mount_wrapper done, (done) ->

    filename = "symlink_target_file.txt"
    filedata = "Hello.\nI'm a symlink target file."
    symlinkname = "symlink.txt"
    # Relative mountpoint symlink will be treated as relative to looproot. Thus we need to realpath
    # mountpoint to avoid this caveat.
    fs.realpath mountpoint, (err, path) ->
      expect(err).toBe(null)
      realmounptoint = path 
      fs.writeFileSync("#{looproot}/#{filename}", filedata)
      fs.symlink "#{realmounptoint}/#{filename}", "#{mountpoint}/#{symlinkname}", (err) ->
        expect(err).toBe(null)
        fs.readFile "#{mountpoint}/#{symlinkname}", (err, data) ->
          expect(err).toBe(null)
          expect(data.toString()).toBe(""+filedata+"")
          done()

# ####################################################################################################
# ####################################################################################################
  it "can create and read relative symlinks", (done) -> default_mount_wrapper done, (done) ->

    filename = "symlink_relative_target_file.txt"
    filedata = "Hello.\nI'm a symlink relative target file."
    dirname = "relcontainer"
    symlinkname = "/symlinkrel.txt"
    symlinktarget = "../symlink_relative_target_file.txt"
    fs.writeFileSync("#{looproot}/#{filename}", filedata)
    fs.mkdirSync("#{looproot}/#{dirname}")
    fs.symlink symlinktarget, "#{mountpoint}/#{dirname}/#{symlinkname}", (err) ->
      expect(err).toBe(null)
      fs.readFile "#{mountpoint}/#{dirname}/#{symlinkname}", (err, data) ->
        expect(err).toBe(null)
        expect(data.toString()).toBe(""+filedata+"")
        done()

####################################################################################################
####################################################################################################
  it "can create directories", (done) -> default_mount_wrapper done, (done) ->

    dirname = "newdir"
    fs.mkdir "#{mountpoint}/#{dirname}", 0o660, (err) ->
      expect(err).toBe(null)
      fs.lstat "#{looproot}/#{dirname}", (err, stats) ->
        expect(err).toBe(null)
        expect(stats.mode).toBe(16816)
        expect(stats.isDirectory()).toBe(true)
        done()

####################################################################################################
####################################################################################################
  it "can remove directories", (done) -> default_mount_wrapper done, (done) ->

    dirname = "newdir2"
    fs.mkdir "#{mountpoint}/#{dirname}", 0o660, (err) ->
      expect(err).toBe(null)
      fs.lstat "#{looproot}/#{dirname}", (err, stats) ->
        expect(err).toBe(null)
        expect(stats.mode).toBe(16816)
        expect(stats.isDirectory()).toBe(true)
        fs.rmdir "#{mountpoint}/#{dirname}",  (err) ->
          expect(err).toBe(null)
          fs.lstat "#{looproot}/#{dirname}", (err, stats) ->
            expect(err.code).toBe("ENOENT")
            done()

####################################################################################################
####################################################################################################
  it "can utimes files", (done) -> default_mount_wrapper done, (done) ->

    filename = "utimes_file.txt"
    filedata = "Hello.\nI'm an utimes file."
    fs.writeFileSync("#{looproot}/#{filename}", filedata)
    fs.readFile "#{mountpoint}/#{filename}", (err, data) ->
      expect(err).toBe(null)
      expect(data.toString()).toBe(""+filedata)
      fs.lstat "#{looproot}/#{filename}", (err, stats) ->
        [ oldatime, oldmtime ] = [ +stats.atime, +stats.mtime ]
        [ newatime, newmtime ] = [ 
          new Date((Math.round(oldatime / 1000) * 1000) - 10000) # Drop ms as they're not considered
          new Date((Math.round(oldmtime / 1000) * 1000) - 10000) # Drop ms as they're not considered
        ]
        fs.utimes "#{mountpoint}/#{filename}", newatime, newmtime, (err) ->
          expect(err).toBe(undefined)
          fs.lstat "#{looproot}/#{filename}", (err, stats) ->
            expect(+stats.atime).toBe(+newatime)
            expect(+stats.mtime).toBe(+newmtime)
            expect(+stats.atime).not.toBe(oldatime)
            expect(+stats.mtime).not.toBe(oldmtime)
            done()

####################################################################################################
####################################################################################################
  it "can statfs", (done) -> default_mount_wrapper done, (done) ->

    child_process.exec "df -h", (err, stdout, stderr) ->
      expect(err).toBe(null)
      expect(stderr).toBe("")
      done()    

####################################################################################################
####################################################################################################
  # Suspended because requires root to chown and I don't expect running this fs as root.
  # fit "can chown files", (done) -> default_mount_wrapper done, (done) ->

  #   filename = "chown_file.txt"
  #   filedata = "Hello.\nI'm a chown file."
  #   fs.writeFile "#{mountpoint}/#{filename}", filedata, (err) ->
  #     expect(err).toBe(null)
  #     expect(fs.readFileSync("#{looproot}/#{filename}").toString()).toBe(filedata)
  #     fs.lstat "#{looproot}/#{filename}", (err, stats) ->
  #       expect(err).toBe(null)
  #       expect(stats.uid).toBe(1000)
  #       expect(stats.gid).toBe(1000)
  #       fs.chown "#{mountpoint}/#{filename}", 1001, 1002, (err) ->
  #         expect(err).toBe(null)
  #         fs.lstat "#{looproot}/#{filename}", (err, stats) ->
  #           expect(err).toBe(null)
  #           expect(stats.uid).toBe(1001)
  #           expect(stats.gid).toBe(1002)
  #           console.log arguments
  #           done()

####################################################################################################
####################################################################################################
  it "meets all the expectations precisely", ->

    expectations["init exceptions are not catchable"] = do ->
      unless expectations["init exceptions are not catchable"]?
        return callhistory.some (call) ->
          call.name is "uncaughtException" &&
          call.time < time.after_mounting_unexistant_looproot &&
          call.time > time.before_mounting_unexistant_looproot &&
          call.env.err.message is "Unexpected exception."

    expectations["init is called prior to all other functions"] = do ->
      init_register = []
      for call in callhistory
        if call.testnum in init_register # Will skip all calls down to first call of next test.
          continue
        else
          unless call.fn is "init" && call.name is "fuse call"
            return false 
          init_register.push(call.testnum)
      return true

    expectations["init always accept only 1 argument"] = callhistory.every (call) ->
      switch
        when call.fn is "init" && call.name is "fuse call"
          return call.args.length is 1
        else
          return true

    init_calls = {}
    expectations["init is called only 1 time per each mount"] = callhistory.every (call) ->
      switch
        when call.fn is "init" && call.name is "fuse call"
          if init_calls[call.testnum]?
            return false
          else
            return (init_calls[call.testnum] = true)
        else
          return true

    expectations["getattr `path` argument always starts with a slash"] = callhistory.every (call) ->
      switch
        when call.fn is "getattr" && call.name is "fuse call"
          return call.env.path[0] is "/"
        else
          return true

    expectations["readdir `path` argument always starts with a slash"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.env.path[0] is "/"
        else
          return true

    expectations["readdir always accepts only 2 arguments"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.args.length is 2
        else
          return true

    expectations["readdir is not called when entry doesn't exists"] = callhistory.every (call) ->
      switch
        when call.fn is "readdir" && call.name is "fuse call"
          return call.env.path isnt "/nonexistantdir"
        else
          return true

    previous_readdir_time = 0
    expectations["readdir is always preceded with gettattr call"] = do ->
      for call, index in callhistory
        if call.fn is "readdir" && call.name is "fuse call"
          current_readdir_time = call.time
          current_readdir_path = call.env.path
          current_readdir_testnum = call.testnum
          return [call.time,callpath,index] unless callhistory.some (call) ->
            call.fn is "getattr" &&
            call.name is "fuse call" &&
            call.time < current_readdir_time &&
            call.time > previous_readdir_time &&
            call.env.path is current_readdir_path &&
            call.testnum is current_readdir_testnum
          previous_readdir_time = call.time
      return true

    expectations["readdir could be called on nonexistant entries under some circumstances"] = do ->
      for call in callhistory
        if call.fn is "readdir" && call.name is "fuse call" && call.env.path is "/readdirtest/dir2"
          return true if callhistory.some (item) ->
            call.fn is "readdir" &&
            item.name is "fuse result" &&
            item.env.err is -2 &&
            item.env.path is "/readdirtest/dir2" &&
            item.zone.number is call.zone.number
      return false

    expectations["fuse implementation functions are not integrated by the `this` context"] = callhistory.every (call) ->
      switch
        when call.name is "fuse call"
          return call.this is global
        else
          return true

    for key, val of expectations
      expect([key,val]).toEqual([key,expectations["all expectations are expected to be true"]])

    if process.env.NODE_ENV is "debug"
      for call, index in callhistory
        console.log "################ #{call.testnum}::#{index} | #{call.time} | #{call.name}"
        console.log call.fn, call.name, call.env #, time.before_reading_deleted_directory, call.time, time.after_reading_deleted_directory

####################################################################################################
####################################################################################################
  it "matches the preformatted description", ->

    preformatted_description = fs.readFileSync("#{testname}.md").toString()
    ERRSTR = "UNEXPECTED VALUE"

    refindex = fs.readFileSync(__filename).toString().split("\n")
    REFGEN = (expectkeys, text, condition) ->
      result = ""
      expectkeys = [expectkeys] unless expectkeys instanceof Array
      unless condition?
        condition = true
        for expectkey in expectkeys
          condition = condition && expectations[expectkey] unless typeof expectkey is 'number'
      result+= if condition then "" else "<del>"
      result+= "<sup>"
      for expectkey in expectkeys
        if typeof expectkey is 'number'
          result+= "[*](/spec/#{path.parse(__filename).base}#L#{expectkey})"
        else
          for line, line_number in refindex
            if line.match(new RegExp("expectations\\[.#{expectkey}.\\]\\s*="))
              result+= "[*](/spec/#{path.parse(__filename).base}#L#{line_number+1})"
      result+= "</sup>"
      result+= text + "."
      result+= if condition then "" else "</del>"
      return result

    generate_formatted_description = ->
      """
      [`fuse-loopback-readwrite`](/#{testname}.coffee) is a moderate-featured loopback linux-only \
      filesystem implementation for a Node.js [`fuse-bindings`](https://github.com/mafintosh/fuse-\
      bindings) package. #{REFGEN(__line,"It consists of " + Object.keys(loopbackfs_instance).length\
      + " functions")} #{REFGEN("fuse implementation functions are not integrated by the `this` \
      context", "The functions are not binded upon mounting into some class instance and `this` by \
      default points to a higher context, usually to `global`")}

      #{REFGEN(__line-9,"This text is backed and generated by [the test in `spec` \
      folder](/spec/#{testname}.spec.coffee)")}

      ### init(cb)
      #{REFGEN("init is called prior to all other functions","Called on filesystem initialization, \
      prior to all other functions")} #{REFGEN("init is called only 1 time per each mount","Called \
      only one time per each mount")} #{REFGEN("init always accept only 1 argument","Always accepts \
      only one input argument")} #{REFGEN("init exceptions are not catchable","There is no way to \
      catch an exception thrown inside of the init code")}

      **Parameters:**  
      `cb` Callback to call after the function done it's work.

      **Return:**  
      Init doesn't return any values. #{REFGEN("init would NOT generate a FUSE error if pass to \
      `cb` anything but 0","It would NOT raise any errors or exceptions if you'll pass an error \
      code to the `cb` as an argument")}
      
      ### getattr(path, cb)
      Called when a path is being stat'ed. #{REFGEN("readdir is always preceded with gettattr call"\
      ,"Getattr call always precede all `readdir` calls")}

      **Parameters:**  
      `path` Path to a file within the FUSE filesystem. #{REFGEN("getattr `path` argument always \
      starts with a slash","Path always starts with a directory separator (slash)")}  
      `cb` Callback to call after the function done it's work.

      **Return:**  
      Returns values by calling the `cb(error_code, stat_data)` callback. `error_code` equal to \
      `0` means no errors. `stat_data` is an object similar to the one returned in node's \
      `fs.stat(path, cb)` and must contain next properties:

      `mtime`: \\<Date object\\>. Modification time. Indicates the time the contents of the file \
      has been changed. Only the contents. Not the attributes. For instance, if you open a file \
      and change some (or all) of its content, its mtime gets updated. If you change a file's \
      attribute (like read-write permissions, metadata), its mtime doesn't change, but ctime will.

      `atime`: \\<Date object\\>. Access time. Indicates the time that a file has been accessed. \
      Any operation performed on the file changes access time.

      `ctime`: \\<Date object\\>. Change time. Whenever anything about a file changes (except its \
      access time), its ctime changes.

      `size`: \\<Int\\>. Size in bytes. As long as directory is just a special type of file \
      which contains list of names and inodes, the concept of size is also applicable to it and \
      the directory size implies the size of the directory file itself and not the number of items \
      in the list or something else.

      `mode`: \\<Int\\>. Mode flags. A bit field containing file type, file access (SUID/SGID) and \
      file permissions flags. The flags can be obtained through Node.js `require('constants')` \
      module. Flags values are defined in `stat.h` linux header file. Most common flags are:

      Constant name | Binary value | Description
      ------------- | ------------ | -----------
      `S_IFMT`   | 0b1111000000000000 | Bitmask for the filetype bitfield. (mask for filetype)
      `S_IFSOCK` | 0b1100000000000000 | Filetype constant of a socket.
      `S_IFLNK`  | 0b1010000000000000 | Filetype constant of a symbolic link.
      `S_IFREG`  | 0b1000000000000000 | Filetype constant of a regular file.
      `S_IFBLK`  | 0b0110000000000000 | Filetype constant of a block device.
      `S_IFDIR`  | 0b0100000000000000 | Filetype constant of a directory.
      `S_IFCHR`  | 0b0010000000000000 | Filetype constant of a character device.
      `S_IFIFO`  | 0b0001000000000000 | Filetype constant of a FIFO named pipe.
      `S_ISUID`  | 0b0000100000000000 | SUID (set-user-ID on execution) bitmask.
      `S_ISGID`  | 0b0000010000000000 | SGID (set-group-ID on execution) bitmask.
      `S_ISVTX`  | 0b0000001000000000 | Sticky bit bitmask.
      `S_IRWXU`  | 0b0000000111000000 | Owner permissions bitmask.
      `S_IRUSR`  | 0b0000000100000000 | Owner permission to read bitmask.
      `S_IWUSR`  | 0b0000000010000000 | Owner permission to write bitmask.
      `S_IXUSR`  | 0b0000000001000000 | Owner permission to execute bitmask.
      `S_IRWXG`  | 0b0000000000111000 | Group permissions bitmask.
      `S_IRGRP`  | 0b0000000000100000 | Group permission to read bitmask.
      `S_IWGRP`  | 0b0000000000010000 | Group permission to write bitmask.
      `S_IXGRP`  | 0b0000000000001000 | Group permission to execute bitmask.
      `S_IRWXO`  | 0b0000000000000111 | Others permissions bitmask.
      `S_IROTH`  | 0b0000000000000100 | Others permission to read bitmask.
      `S_IWOTH`  | 0b0000000000000010 | Others permission to write bitmask.
      `S_IXOTH`  | 0b0000000000000001 | Others permission to execute bitmask.

      `uid`: \\<Int\\>. File owner identifier (UID). A unique positive integer assigned by an \
      operating system to each user. Each user is identified to the system by its UID, and user \
      names are generally used only as an interface for humans.  
      The Linux Standard Base Core Specification specifies that UID values in the range 0 to 99 \
      should be statically allocated by the system, and shall not be created by applications, \
      while UIDs from 100 to 499 should be reserved for dynamic allocation by system \
      administrators and post install scripts.  
      On FreeBSD, porters who need a UID for their package can pick a free one from the range 50 \
      to 999 and then register this static allocation in ports/UIDs. Some POSIX systems allocate \
      UIDs for new users starting from 500 (OS X, Red Hat Enterprise Linux), others start at 1000 \
      (openSUSE, Debian[6]). On many Linux systems, these ranges are specified in \
      `/etc/login.defs`, for `useradd` and similar tools.  
      Central UID allocations in enterprise networks (e.g., via LDAP and NFS servers) may limit \
      themselves to using only UID numbers well above 1000, to avoid potential conflicts with \
      UIDs locally allocated on client computers. NFSv4 can help avoid numeric identifier \
      collisions, by identifying users (and groups) in protocol packets using "user@domain" \
      names rather than integer numbers, at the expense of additional translation steps.

      `gid`: \\<Int\\>. File owner group identifier (GID). A unique positive integer assigned by \
      an operating system to each group. Each group is identified to the system by its GID, and \
      group names are generally used only as an interface for humans. Many Linux systems reserve \
      the GID number range 0 to 99 for statically allocated groups, and either 100−499 or 100−999 \
      for groups dynamically allocated by the system in post-installation scripts. These ranges \
      are often specified in `/etc/login.defs`, for `useradd`, `groupadd` and similar tools.

      ### readdir(path, cb)
      Called when a directory is being listed. #{REFGEN("readdir always accepts only 2 arguments", \
      "Always accepts only two input arguments")} #{REFGEN("readdir is always preceded with \
      gettattr call","Always preceded with a `gettattr` call")} #{REFGEN("readdir is not called \
      when entry doesn't exists","Readdir is not called if the `path` entry wasn't listed by \
      parent directory readdir call or preceding `getattr` returned an error (in common - if the \
      entry doesn't exists)")} #{REFGEN(["readdir could be called on nonexistant entries under some \
      circumstances","readdir returns weird stuff to `fs.readdir` when called on nonexistant"], \
      "However it is possible to simulate the situation when `readdir` is called on a nonexistant \
      entry but in that case error is ignored (possible bug) and `entries_array` is returned \
      instead")}

      **Parameters:**  
      `path` Path to a file within the FUSE filesystem. #{REFGEN("readdir `path` argument always \
      starts with a slash","Path always starts with a directory separator (slash)")}  
      `cb` Callback to call after the function done it's work.

      **Return:**  
      Returns values by `cb(error_code, entries_array)` callback. `entries_array` is an array of \
      strings of entries names which requested `path` contains. #{REFGEN(["readdir returns empty \
      array if entries_list is undefined","readdir returns empty array if entries_list is null"],\
      "Readdir will return empty array if `entries_array` passed to `cb` is null or undefined")}

      ### create(path, mode, cb)
      Called when a new file is being opened. And what it is supposed to do???

      **Parameters:**  

      **Return:**  
      Returns values by `cb(error_code)` callback.
      """

    if process.env.NODE_ENV is "debug"
      #console.dir preformatted_description
      #console.dir generate_formatted_description()
      console.log "---------"
      console.log generate_formatted_description()

    if process.env.NODE_ENV is "savetext"
      fs.writeFileSync("./fuse-loopback-readwrite.md",generate_formatted_description())

    expect(
      generate_formatted_description() is preformatted_description
    ).toBe(true)