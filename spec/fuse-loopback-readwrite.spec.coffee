[ fs, fuse, path, child_process, fusefs, domain ] = [ 
  (require "fs-extra"),(require "fuse-bindings"),(require "path"),(require "child_process"),
  (require "../fuse-loopback-readwrite.coffee"),(require "domain")
]
####################################################################################################
####################################################################################################
describe "Fuse-bindings loopback read-write filesystem implementation", ->
  time = {}
  specdata = { assumptions: {}, fusecalls: [] }
  testname = path.basename(path.basename(__filename,".coffee"),".spec")
  looproot = "data/#{testname}-looproot"
  mountpoint = "data/#{testname}-mountpoint"
  expectations =
    # Readdir expectations.
    "readdir accepts 2 arguments"                                             : undefined
    "readdir's path argument starts with a slash"                             : undefined
    "readdir is not called when entry doesn't exists"                         : undefined
    # Other expectations.
    "fuse implementation functions are not integrated by the `this` context"  : undefined
  zones_counter = 0
  eventshistory = []
  fs.emptyDirSync(looproot)
  fs.emptyDirSync(mountpoint)
  testfs = fusefs(root:looproot)
  origin =
    init: testfs.init
    readdir: testfs.readdir
  testfs.init = (cb) ->
    if @ is global
      expectations["fuse implementation functions are not integrated by the `this` context"] = true
    origin.init(cb)
  testfs.readdir = (path, cb) ->
    zone = domain.create()
    zone.number = zones_counter++
    eventshistory.push(
      fn: "readdir"
      name: "fuse call"
      path: path
      zone: zone
      date: new Date()
      arguments: arguments
    )
    zone.run =>
      origin.readdir path, (err, files) ->
        eventshistory.push(
          fn: "readdir"
          name: "fuse call result"
          path: path
          zone: domain.active
          date: new Date()
          arguments: arguments
        )
        cb(err,files)

####################################################################################################
####################################################################################################
  it "mounts", (done) ->

    fuse.mount mountpoint, testfs, (err) ->
      expect(arguments.length).toBe(1)
      expect(err).toBe(undefined)
      setTimeout(done,100)

####################################################################################################
####################################################################################################
  it "has working `readdir` functional", (done) ->

    fs.mkdirSync(looproot + "/readdirtest")
    fs.mkdirSync(looproot + "/readdirtest/dir1")
    time.before_readdirtest_ls = new Date()
    child_process.exec "ls #{mountpoint}/readdirtest", ->
      time.after_readdirtest_ls = new Date()
      child_process.exec "ls #{mountpoint}/nonexistantdir", ->
        check_expectations()

    check_expectations = ->
      expectations["readdir accepts 2 arguments"] = eventshistory.some (event) ->
        time.before_readdirtest_ls < event.date < time.after_readdirtest_ls  &&
        event.path is "/readdirtest" &&
        event.name is "fuse call" &&
        event.fn is "readdir" &&
        event.arguments.length is 2
      expectations["readdir's path argument starts with a slash"] = eventshistory.some (event) ->
        time.before_readdirtest_ls < event.date < time.after_readdirtest_ls  &&
        event.name is "fuse call" &&
        event.fn is "readdir" &&
        event.path[0] is "/"
      expectations["readdir is not called when entry doesn't exists"] = not eventshistory.some (event) ->
        event.fn is "readdir" &&
        event.path is "/nonexistantdir"
      done()

####################################################################################################
####################################################################################################
  it "unmounts", (done) ->

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

####################################################################################################
####################################################################################################
  it "meets all the expectations precisely", ->

    for key, val of expectations
      expect([key,val]).toEqual([key,true])