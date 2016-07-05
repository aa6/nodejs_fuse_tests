[ fs,fuse ] = [ (require "fs"),(require "fuse-bindings") ]  

# Functions enough to implement read-only filesystem:
# - readdir(path,cb)
node_open_modes = 
[
  { mode: 'rs+' , value: 0b00000000000000001001000000000010 }
  { mode: 'rs'  , value: 0b00000000000000001001000000000000 }
  { mode: 'a+'  , value: 0b00000000000000001000010000000010 }
  { mode: 'a'   , value: 0b00000000000000001000010000000001 }
  { mode: 'r+'  , value: 0b00000000000000001000000000000010 } # w+ is a sad joke
  { mode: 'w'   , value: 0b00000000000000001000000000000001 }
  { mode: 'r'   , value: 0b00000000000000001000000000000000 }
]

module.exports = ({
  root
}) ->

  fds = { counter: 0 }
  root = root.replace(/\/+$/,"") # Ensure there would be no trailing slash.

  init: (cb) ->
    # console.log "init", arguments
    cb()

  getattr: (path, cb) ->
    # console.log "getattr", arguments
    fs.lstat (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  readdir: (path, cb) ->
    # console.log "readdir", arguments
    fs.readdir (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  create: (path, mode, cb) ->
    # console.log "create", arguments
    fs.open root + path, "w", (err, result_fd) ->
      fs.fchmod result_fd, mode, ->
        fds[return_fd = ++fds.counter] = result_fd
        cb(0,return_fd)

  open: (path, flags, cb) ->
    # console.log "open", arguments
    mode = do -> for node_mode in node_open_modes
      return node_mode.mode if (flags & node_mode.value) is node_mode.value
    cb(fuse.ENOSYS) unless mode?
    fs.open root + path, mode, (err, result_fd) ->
      fds[return_fd = ++fds.counter] = result_fd
      switch
        when !err
          cb(0,return_fd)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  write: (path, fd, buffer, length, position, cb) ->
    # console.log "write", arguments
    # console.log "fds fd", fds[fd]
    fs.write fds[fd], buffer, 0, length, position, (err, written, buffer) ->
      switch
        when !err
          cb(written)
        else
          cb(0)

  destroy: (cb) ->
    # console.log "destroy", arguments
    cb(0)

  release: (path, fd, cb) ->
    # console.log "release", arguments
    cb(0)

  releasedir: (path, fd, cb) ->
    # console.log "releasedir", arguments
    cb(0)

  read: (path, fd, buf, len, pos, cb) ->
    # console.log "read", arguments
    fs.read fds[fd], buf, 0, len, pos, (err, bytes_read, buf) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  fsync: (path, fd, datasync, cb) ->
    # console.log "fsync", arguments
    fs.fsync fds[fd], (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  truncate: (path, len, cb) ->
    #console.log "truncate", arguments
    fs.truncate root + path, len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  ftruncate: (path, fd, len, cb) ->
    #console.log "ftruncate", arguments
    fs.ftruncate fds[fd], len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  unlink: (path, cb) ->
    # console.log "unlink", arguments
    fs.unlink root + path, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err    

  mkdir: (path, mode, cb) ->
    # console.log "mkdir", arguments
    fs.mkdir root + path, mode, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  
          
  rmdir: (path, cb) ->
    # console.log "rmdir", arguments
    fs.rmdir root + path, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  

  chown: (path, uid, gid, cb) ->
    fs.chown root + path, uid, gid, (err) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  chmod: (path, mode, cb) ->
    # console.log "chmod", arguments
    fs.chmod root + path, mode, (err) ->
      switch
        when !err
          cb(0)
        else
          cb(fuse[err.code])

  rename: (src, dest, cb) ->
    # console.log "rename", arguments
    fs.rename root + src, root + dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err






  ##########################################

  symlink: (src, dest, cb) ->
    # console.log "symlink", arguments
    fs.symlink src, dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  

  readlink: (path, cb) ->
    # console.log "readlink", arguments
    fs.readlink path, (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  utimens: (path, atime, mtime, cb) ->
    # console.log "utimens", arguments
    fs.utimes path, atime, mtime, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err
 
  # Creates hard link.
  link: (src, dest, cb) ->
    # console.log "link", arguments
    fs.link src, dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err    

#   statfs: = (path, cb) ->
#     console.log "statfs", arguments
#     cb(0, {
#       bsize: 1000000,
#       frsize: 1000000,
#       blocks: 1000000,
#       bfree: 1000000,
#       bavail: 1000000,
#       files: 1000000,
#       ffree: 1000000,
#       favail: 1000000,
#       fsid: 1000000,
#       flag: 1000000,
#       namemax: 1000000
#     })
#   }