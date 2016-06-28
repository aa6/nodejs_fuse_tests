[ fs,fuse ] = [ (require "fs"),(require "fuse-bindings") ]  

# Functions enough to implement read-only filesystem:
# - readdir(path,cb)
node_open_modes = 
  'r'  : 0b00000000000000001000000000000000
  'r+' : 0b00000000000000001000000000000010
  'rs' : 0b00000000000000001001000000000000
  'rs+': 0b00000000000000001001000000000010
  'w'  : 0b00000000000000001000000000000001
  'w+' : 0b00000000000000001000000000000010
  'a'  : 0b00000000000000001000010000000001
  'a+' : 0b00000000000000001000010000000010

module.exports = ({
  root
}) ->

  fds = { counter: 0 }
  root = root.replace(/\/+$/,"") # Ensure there would be no trailing slash.

  init: (cb) ->
    # Ensure root is an existing directory.
    cb()

  readdir: (path, cb) ->
    fs.readdir (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  getattr: (path, cb) ->
    fs.lstat (root + path), (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  fgetattr: (path, fd, cb) ->
    fs.fstat fds[fd], (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  open: (path, flags, cb) ->
    mode = do -> for node_mode, node_flags of node_open_modes
      return node_mode if flags & node_flags is node_flags
    cb(fuse.ENOSYS) unless mode?
    fs.open path, mode, (err, result_fd) ->
      fds[return_fd = ++fds.counter] = result_fd
      switch
        when !err
          cb(0,return_fd)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  read: (path, fd, buf, len, pos, cb) ->
    fs.read fds[fd], buf, len, pos, (err, bytes_read, buf) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  fsync: (path, fd, datasync, cb) ->
    fs.fsync fds[fd], (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  truncate: (path, len, cb) ->
    fs.truncate path, len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  ftruncate: (path, fd, size, cb) ->
    fs.ftruncate fds[fd], len, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  readlink: (path, cb) ->
    fs.readlink path, (err, result) ->
      switch
        when !err
          cb(0,result)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  chown: (path, uid, gid, cb) ->
    fs.chown path, uid, gid, (err) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  chmod: (path, mode, cb) ->
    fs.chmod path, mode, (err) ->
      switch
        when !err
          cb(bytes_read)
        else
          cb(0)

  write: (path, fd, buffer, length, position, cb) ->
    fs.write fds[fd], buffer, length, position, (err, written, buffer) ->
      switch
        when !err
          cb(written)
        else
          cb(0)

  utimens: (path, atime, mtime, cb) ->
    fs.utimes path, atime, mtime, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err

  unlink: (path, cb) ->
    fs.unlink path, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err      

  rename: (src, dest, cb) ->
    fs.rename src, dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err   

  # Creates hard link.
  link: (src, dest, cb) ->
    fs.link src, dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err   

  symlink: (src, dest, cb) ->
    fs.symlink src, dest, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err   

  mkdir: (path, mode, cb) ->
    fs.mkdir path, mode, (err) ->
      switch
        when !err
          cb(0)
        when fuse[err.code]?
          cb(fuse[err.code])
        else
          throw err  
          
  rmdir: (path, cb) ->
    fs.rmdir path, (err) ->
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