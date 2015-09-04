$ = require('jquery')
_ = require('lodash')

Configuration = require('./configuration.coffee')
Theme = require('./theme.coffee')
Player = require('./player.coffee')
ProgressBar = require('./progress_bar.coffee')
Embed = require('./embed.coffee')
Feed = require('./feed.coffee')

ChapterMarks = require('./extensions/chaptermarks.coffee')
ChromeCast = require('./extensions/chromecast.coffee')
EpisodeInfo = require('./extensions/episode_info.coffee')
Playlist = require('./extensions/playlist.coffee')
Transcript = require('./extensions/transcript.coffee')
Waveform = require('./extensions/waveform.coffee')

class PodigeePodcastPlayer
  constructor: (@elemClass) ->
    @getConfiguration().loaded.done =>
      @renderTheme().done =>
        @initPlayer()

  extensions: {}

  getFeed: () ->
    return unless @podcast.feed

    @podcast.feed = new Feed(@podcast.feed)

  getProductionData: () ->
    return unless @episode.productionDataUrl

    self = @
    $.getJSON(@episode.productionDataUrl).done (data) =>
      self.episode.productionData = data.data

  getConfiguration: () ->
    new Configuration(this)

  renderTheme: =>
    rendered = $.Deferred()
    @theme = new Theme(this)
    @theme.loaded.done =>
      @elem = @theme.render()
      rendered.resolve()

    rendered.promise()

  initPlayer: =>
    mediaElem = @elem.find('audio')[0]
    new Player(mediaElem, @options, @init)

  init: (player) =>
    @player = player
    @initProgressBar()
    @bindButtons()
    @bindPlayerEvents()
    @initializeExtensions()
    window.setTimeout @sendHeightChange, 0

  # initialize elements

  initProgressBar: ->
    @progressBar = new ProgressBar(
      @theme.progressBarElement,
      @player.media,
      @options.timeMode,
    )

  togglePlayState: (elem) =>
    @elem.toggleClass('playing')
    @theme.playPauseElement.toggleClass('fa-play')
    @theme.playPauseElement.toggleClass('fa-pause')

  # event handlers

  updateTime: () =>
    timeString = @progressBar.updateTime()
    @adjustPlaySpeed(timeString)

  updateLoaded: () =>
    @progressBar.updateLoaded()

  triggerLoading: =>
    @updateLoaded()
    @progressBar.showBuffering()

  triggerPlaying: =>
    @updateLoaded()
    @progressBar.hideBuffering()

  triggerLoaded: =>
    @updateLoaded()
    @progressBar.hideBuffering()

  triggerEnded: =>
    @player.media.setCurrentTime(0)
    @progressBar.updateTime()
    @togglePlayState(this)

  triggerError: =>
    @progressBar.hideBuffering()

  tempPlayBackSpeed: null
  adjustPlaySpeed: (timeString) =>
    return unless @episode.productionData

    currentTime = @player.media.currentTime
    item = $.grep @episode.productionData.statistics.music_speech, (item, index) ->
      item.start.indexOf(timeString) != -1

    if item.length
      if item[0].label == 'music'
        unless @options.currentPlaybackRate == 1.0
          @tempPlayBackSpeed = @options.currentPlaybackRate
          @player.setPlaySpeed(1.0)
      else
        if @tempPlayBackSpeed
          @player.setPlaySpeed(@tempPlayBackSpeed)
          @tempPlayBackSpeed = null

    @updateSpeedDisplay()

  bindButtons: () =>
    @theme.playPauseElement.click =>
      if @extensions.ChromeCast && @extensions.ChromeCast.active
        @extensions.ChromeCast.togglePlayState()
      else
        if @player.media.paused
          @player.media.play()
        else
          @player.media.pause()
      @togglePlayState(this)

    @theme.backwardElement.click =>
      @player.jumpBackward()

    @theme.forwardElement.click =>
      @player.jumpForward()

    @theme.speedElement.click (event) =>
      @player.changePlaySpeed()
      @updateSpeedDisplay()

  updateSpeedDisplay: () ->
    @theme.speedElement.text("#{@options.currentPlaybackRate}x")

  bindPlayerEvents: () ->
    $(@player.media).on('timeupdate', @updateTime)
      .on('play', @triggerPlaying)
      .on('playing', @triggerPlaying)
      .on('seeking', @triggerLoading)
      .on('seeked', @triggerLoaded)
      .on('waiting', @triggerLoading)
      .on('loadeddata', @triggerLoaded)
      .on('canplay', @triggerLoaded)
      .on('ended', @triggerEnded)
      .on('error', @triggerError)
      #.on('progress', @triggerLoading)

  renderPanel: (extension) =>
    @theme.addButton(extension.button)
    @theme.addPanel(extension.panel)

  initializeExtensions: () =>
    self = this
    [ChapterMarks, EpisodeInfo, Playlist, Waveform, Transcript].forEach (extension) =>
      self.extensions[extension.extension.name] = new extension(self)

  animationOptions: ->
    duration: 300
    step: @sendHeightChange

  togglePanel: (elem) =>
    elem.slideToggle(@animationOptions())

  sendHeightChange: =>
    paddingTop = parseInt(@elem.css('padding-top'), 10)
    paddingBottom = parseInt(@elem.css('padding-bottom'), 10)
    newHeight = @elem.height() + paddingTop + paddingBottom
    resizeData = JSON.stringify({
      id: @options.id,
      listenTo: 'resizePlayer',
      height: newHeight
    })
    window.parent.postMessage(resizeData, '*')

unless window.inEmbed
  new Embed()
else
  window.PodigeePodcastPlayer = PodigeePodcastPlayer
