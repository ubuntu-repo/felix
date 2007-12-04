import sys
import os
import pickle

from fbuild.flxbuild.flxutil import unix2native
import interscript.frames.inputf

class setup_test:
  def __init__(self, iframe, root,
      zfill_pattern=[1],
      zfill_default=2):
    self.iframe = iframe
    self.root = root
    self.zfill_pattern = zfill_pattern
    self.zfill_default = 2

    self.native_root = unix2native(self.root)
    self.levels = []
    self.testcount = 0
    self.argcount = 0

    self.names_written = {}

    self.katfile = self.root + 'categories'

    if os.path.exists(self.katfile):
      f = open(self.katfile)
      try:
        self.registry_in = pickle.load(f)
      finally:
        f.close()
    else:
      self.registry_in = {}

    self.registry_out = {}


  def head(self, level, title=None):
    if not self.levels and level > 1:
      self.levels = [1]

    self.testcount = 0
    self.argcount = 0

    while len(self.levels) < level:
      self.levels.append(0)

    self.levels[level - 1] = self.levels[level - 1] + 1
    self.levels = self.levels[:level]

    if title is None:
      title = self.root + self.level_str()

    return self.iframe.head(level, title)


  def level_str(self):
    levels = []
    for i in range(len(self.levels)):
      try:
        z = self.zfill_pattern[i]
      except IndexError:
        z = self.zfill_default

      levels.append(str(self.levels[i]).zfill(z))

    return '.'.join(levels)


  def filename(self):
    return self.root + self.level_str()


  def tangler(self, name,
      extension='',
      filetype=interscript.frames.inputf.deduce):

    path = name + extension
    if path in self.names_written:
      print 'file:', path, 'already created!'

      # XXX: NEED TO GENERATE A NEW FILE NAME
      # XXX: what's the proper way to error out an interscript file?
      sys.exit(1)

    h = self.iframe.tangler(path, filetype)
    self.names_written[path] = h

    return h


  def test(self, *args, **kwds):
    name = '%s-%s' % (self.filename(), self.testcount)


    # if categories are specified, write them out
    categories = []
    if 'categories' in kwds:
      categories = kwds['categories']
      del kwds['categories']

    # construct the tangler
    tangler = apply(self.tangler, (name,) + args, kwds)
    for cat in categories: self.kat(tangler,cat)

    self.testcount = self.testcount + 1
    return tangler

  def expect(self):
    name = '%s-%s' % (self.filename(), self.testcount - 1)

    return self.tangler(name, '.expect', 'data')


  def args(self, arguments):
    name = '%s-%s-%s' % (self.filename(), self.testcount - 1, self.argcount)
    self.argcount = self.argcount + 1

    a = self.tangler(name, '.args', 'data')

    select(a)
    tangle(arguments)
    doc()

    return a


  def test_args(self, arglist, *args, **kwds):
    t = apply(self.test, args, kwds)

    for arguments in arglist:
      self.args(arguments)

    return t


  def expect_args(self, arguments):
    self.args(arguments)

    name = '%s-%s-%s' % (self.filename(), self.testcount - 1, self.argcount - 1)

    return self.tangler(name, '.argexpect', 'data')


  def kat(self, tangler, code):
    tangler.writeline(
      "//Check " + code,
      self.iframe.original_filename,
      self.iframe.original_count
    )

    f = tangler.sink.filename
    ff = f.split('/')[-1][:-4]
    v = self.registry_out.get(code,[])
    if ff not in v:
      self.iframe.set_anchor(ff)
      v.append(ff)
      self.registry_out[code]=v


  def emit_katlist(self):
    self.iframe.begin_list("keyed")
    keys = self.registry_in.keys()
    keys.sort()
    for k in keys:
      v = self.registry_in[k]
      self.iframe.item(k)
      first = 1
      for i in v:
        if first: first = 0
        else: self.iframe.weave(", ")
        self.iframe.ref_anchor(i)
    self.iframe.end_list()


  def write_katfile(self):
    dirname = os.path.split(self.katfile)[0]
    if not os.path.exists(dirname):
      os.makedirs(dirname)

    f = open(self.katfile, 'w')
    try:
      pickle.dump(self.registry_out, f)
    finally:
      f.close()
