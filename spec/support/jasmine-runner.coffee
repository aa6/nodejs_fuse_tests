Jasmine = require('jasmine')
SpecReporter = require('jasmine-spec-reporter')
noop = ->

jrunner = new Jasmine()
jrunner.configureDefaultReporter({print: noop})    # remove default reporter logs
jasmine.getEnv().addReporter(new SpecReporter())   # add jasmine-spec-reporter
jrunner.loadConfigFile()                           # load jasmine.json configuration
jrunner.execute()