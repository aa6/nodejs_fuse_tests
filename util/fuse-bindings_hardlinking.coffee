[ fs, fuse, child_process ] = [ 
  (require "fs-extra"),(require "fuse-bindings"),(require "child_process") 
]

mountdir = process.env.MOUNTDIR ? "tmp/fuse-bindings_hardlinking_mountpoint"
fs.ensureDirSync(mountdir)
mountdir = fs.realpathSync(mountdir)

fs_tree = 

  fds: { counter: 0 }
  "/":
    mtime: new Date()
    atime: new Date()
    ctime: new Date()
    size: 100
    mode: 16877
    uid: process.getuid()
    gid: process.getgid()

  "/test":
    mtime: new Date()
    atime: new Date()
    ctime: new Date()
    size: 12
    mode: 33188
    uid: process.getuid()
    gid: process.getgid()
    str: "hello world"

fs_instance = 

  readdir: (path, cb) ->
    console.log "readdir", arguments
    cb(0, (key for key of fs_tree when key.indexOf(path) is 0))

  getattr: (path, cb) ->
    console.log "getattr", arguments
    if fs_tree[path]?
      cb(0,fs_tree[path])
    else
      cb(fuse.ENOENT)

  open: (path, flags, cb) ->
    console.log "open", arguments
    if fs_tree[path]?
      fs_tree.fds[fd = ++fs_tree.fds.counter] =
        path: path
        flags: flags
      cb(0,fd)
    else
      cb(fuse.ENOENT)

  read: (path, fd, buf, len, pos, cb) ->
    console.log "read", arguments
    if fs_tree[fs_tree.fds[fd].path]?
      str = fs_tree[fs_tree.fds[fd].path].str
      str = str.slice(pos)
      buf.write(str)
      cb(str.length)
    else
      cb(fuse.ENOENT)

  link: (src, dst, cb) ->
    console.log "LINK!", arguments
    cb(0)

mount_fs_instance = (done) ->
  fuse.mount mountdir, fs_instance, (err) ->
    console.log "mount", arguments
    setTimeout(done,100)

umount_fs_instance = (done) ->
  setTimeout(
    ->
      child_process.exec "fusermount -u #{mountdir}", (err, stdout, stderr) ->
        console.log "umount", arguments
        done() if done?
    100
  )

mount_fs_instance ->
  console.log "=== link 1 ==="
  fs.link "#{mountdir}/test", "#{mountdir}/test-lnk", ->
    console.log arguments
    console.log "=== /link 1 ==="
    console.log "=== link 2 ==="
    fs.link "#{mountdir}/test-lnk", "#{mountdir}/test", ->
      console.log arguments
      console.log "=== /link 2 ==="
      console.log "=== readFile ==="
      fs.readFile "#{mountdir}/test", (err, data) ->
        console.log data.toString()
        console.log "=== /readFile ==="
        umount_fs_instance()