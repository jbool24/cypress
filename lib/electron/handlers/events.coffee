_           = require("lodash")
ipc         = require("electron").ipcMain
shell       = require("electron").shell
cyIcons     = require("@cypress/core-icons")
dialog      = require("./dialog")
project     = require("./project")
pgk         = require("./package")
cookies     = require("./cookies")
logs        = require("./logs")
Renderer    = require("./renderer")
open        = require("../../util/open")
user        = require("../../user")
logger      = require("../../logger")
errors      = require("../../errors")
Updater     = require("../../updater")
Project     = require("../../project")
api         = require("../../api")

handleEvent = (options, bus, event, id, type, arg) ->
  sendResponse = (data = {}) ->
    try
      logger.info("sending ipc data", type: type, data: data)
      event.sender.send("response", data)

  sendErr = (err) ->
    sendResponse({id: id, __error: errors.clone(err, {html: true})})

  send = (data) ->
    sendResponse({id: id, data: data})

  onBus = (event) ->
    bus.removeAllListeners(event)
    bus.on(event, send)

  switch type
    when "on:menu:clicked"
      onBus("menu:item:clicked")

    when "on:app:event"
      onBus("app:events")

    when "on:focus:tests"
      onBus("focus:tests")

    when "gui:error"
      logs.error(arg)
      .then -> send(null)
      .catch(sendErr)

    when "show:directory:dialog"
      dialog.show()
      .then(send)
      .catch(sendErr)

    when "log:in"
      user.logIn(arg)
      .then(send)
      .catch(sendErr)

    when "log:out"
      user.logOut()
      .then(send)
      .catch(sendErr)

    when "get:current:user"
      user.get()
      .then(send)
      .catch(sendErr)

    when "clear:github:cookies"
      cookies.clearGithub(event.sender.session.cookies)
      .then(send)
      .catch(sendErr)

    when "external:open"
      shell.openExternal(arg)

    when "on:launch:browser"
      project.onRelaunch(send)

    when "close:browser"
      project.closeBrowser()
      .then(send)
      .catch(sendErr)

    when "launch:browser"
      # headless.createRenderer(arg, true)
      project.launch(arg.browser, arg.url, arg.spec, {
        onBrowserOpen: ->
          send({browserOpened: true})
        onBrowserClose: ->
          ## ensure the state is correct
          project.closeBrowser()

          send({browserClosed: true})
      })
      .catch(sendErr)

    when "change:browser:spec"
      project.changeToSpec(arg.spec)
      .then(send)
      .catch(sendErr)

    when "get:open:browsers"
      project.getBrowsers()
      .then(send)
      .catch(sendErr)

    when "window:open"
      Renderer.create(arg)
      .then(send)
      .catch(sendErr)

    when "window:close"
      Renderer.getByWebContents(event.sender).destroy()

    when "open:finder"
      open.opn(arg)
      .then(send)
      .catch(sendErr)

    when "get:options"
      pgk(options)
      .then(send)
      .catch(sendErr)

    when "updater:check"
      Updater.check({
        onNewVersion: ->   send(true)
        onNoNewVersion: -> send(false)
      })

    when "updater:run"
      echo = (event, version) ->
        send({event: event, version: version})

      upd = Updater.run({
        onStart: -> echo("start")
        onApply: -> echo("apply")
        onError: -> echo("error")
        onDone: ->  echo("done")
        onNone: ->  echo("none")
        onDownload: (version) ->
          echo("download", version)
      })

      ## TODO: there is no note here, what if the window
      ## is closed once the updater finishes?
      win = Renderer.getByWebContents(event.sender)
      win.once "closed", ->
        upd.cancel()

    when "get:logs"
      logs.get()
      .then(send)
      .catch(sendErr)

    when "clear:logs"
      logs.clear()
      .then -> send(null)
      .catch(sendErr)

    when "on:log"
      logs.onLog(send)

    when "off:log"
      logs.off()
      send(null)

    when "get:orgs"
      Project.getOrgs()
      .then(send)
      .catch(sendErr)

    when "get:projects"
      Project.getPathsAndIds()
      .then(send)
      .catch(sendErr)

    when "get:project:statuses"
      Project.getProjectStatuses(arg)
      .then(send)
      .catch(sendErr)

    when "get:project:status"
      Project.getProjectStatus(arg)
      .then(send)
      .catch(sendErr)

    when "add:project"
      Project.add(arg)
      .then(send)
      .catch(sendErr)

    when "remove:project"
      Project.remove(arg)
      .then -> send(arg)
      .catch(sendErr)

    when "open:project"
      getConfig = ->
        project.opened()
        .getConfig()
        .then(send)
        .catch(sendErr)

      openProject = ->
        project.open(arg, options, {
          onFocusTests: onFocusTests
          onSpecChanged: onSpecChanged
          onSettingsChanged: onSettingsChanged
        })
        .then(getConfig)
        .catch(sendErr)

      onSettingsChanged = ->
        project.reboot()
        .then(openProject)

      onSpecChanged = (spec) ->
        send({specChanged: spec})

      onFocusTests = ->
        if _.isFunction(options.onFocusTests)
          options.onFocusTests()

        bus.emit("focus:tests")

      ## initially open!
      openProject()

    when "close:project"
      project.close()
      .then(send)
      .catch(sendErr)

    when "setup:dashboard:project"
      project.createCiProject(arg)
      .then(send)
      .catch(sendErr)

    when "get:record:keys"
      project.getRecordKeys()
      .then(send)
      .catch(sendErr)

    when "get:specs"
      project.getSpecChanges({
        onChange: send
        onError: sendErr
      })

    when "get:builds"
      project.getBuilds()
      .then(send)
      .catch (err) ->
        err.type = if _.get(err, "statusCode") is 401
          "UNAUTHENTICATED"
        else if _.get(err, "cause.code") is "ESOCKETTIMEDOUT"
          "TIMED_OUT"
        else if _.get(err, "code") is "ENOTFOUND"
          "NO_CONNECTION"
        else
          err.type or "UNKNOWN"

        sendErr(err)

    when "request:access"
      project.requestAccess(arg)
      .then(send)
      .catch (err) ->
        err.type = if _.get(err, "statusCode") is 403
          "ALREADY_MEMBER"
        else if _.get(err, "statusCode") is 422 and /existing/.test(err.errors?.userId?.join(''))
          "ALREADY_REQUESTED"
        else
          err.type or "UNKNOWN"

        sendErr(err)

    else
      throw new Error("No ipc event registered for: '#{type}'")

module.exports = {
  handleEvent: handleEvent

  stop: ->
    ipc.removeAllListeners()

  start: (options, bus) ->
    ## curry left options
    ipc.on "request", _.partial(@handleEvent, options, bus)

}