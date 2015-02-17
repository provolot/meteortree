Tutorials = new Mongo.Collection("tutorials")
Steps = new Mongo.Collection("steps")
Links = new Mongo.Collection("deps")
Icons = new FS.Collection("icons", {
  stores: [new FS.Store.FileSystem("icons")]
});

if Meteor.isClient
	
	# counter starts at 0
	Session.set "dep-mode", "False"
	nodes_dep = new Deps.Dependency()
	steps_dep = new Deps.Dependency()
	jsPlumb.setContainer($("#jsPlumbContainer"))

	Template.body.helpers
		tutorials: ->
			if(Meteor.user())
				Tutorials.find {},
					sort:
						createdAt: -1
			else
				Tutorials.find  {},
					sort:
						createdAt: -1
	


	Template.body.events
		"click .save-draft": (event) ->
			allTuts = Tutorials.find({}).fetch()
			_.each allTuts, (t) ->
				console.log t
				Tutorials.update t._id,
					$set:
						x: t.draft_x
						y: t.draft_y
			$("body").removeClass "draft-mode"
			$(".node").removeClass "draft-node"
			Session.set "draft-mode", "False"
	
		"click .discard-draft": ->
			if(Meteor.user())
				allTuts = Tutorials.find({}).fetch()
				_.each allTuts, (t) ->
					console.log t
					Tutorials.update t._id,
						$set:
							draft_x: t.x
							draft_y: t.y
				$("body").removeClass "draft-mode"
				$(".node").removeClass "draft-node"
				Session.set "draft-mode", "False"

		
		"submit .new-tutorial": (event) ->
			
			# This function is called when the new tutorial form is submitted
			title = "New Tutorial"
			x = 15
			y = 15
			Tutorials.insert
				title: title
				publishMode: "draft"
				draft_x: x
				draft_y: y
				x: x
				y: y
				createdAt: new Date() # current time
				createdById: Meteor.userId()
				createdByUsername: Meteor.user().username
			# Clear form
			event.target.title.value = ""
			nodes_dep.changed
			
			# Prevent default form submit
			return false

		"submit .update-tutorial": ->
			event.preventDefault();
			$(".tutorial").find(".edit-form").hide('slide', { 'direction': 'right'}, 300);
			title = event.target.title.value

			if($(".tutorial#" + this._id + " input[name='publishMode']").is(":checked"))
				publishMode = "publish"
			else
				publishMode = "draft"

			Tutorials.upsert this._id,
				$set:  
					title: title
					publishMode: publishMode
					updatedAt: new Date() # current time
					updatedById: Meteor.userId()
					updatedByUsername: Meteor.user().username
			return false


	Template.tutorial.helpers
		steps: ->
			Steps.find
				tutorial_id: this._id
			,
				sort:
					ordinal: -1
		nodeIcon: ->
			icon = Icons.findOne({tutorial_id:this._id})
			if(icon)
				imgurl = '/uploads/' + icon.filename
			else
				imgurl = DEFAULT_ICON
			return "<img src='" + imgurl + "'>"

		publishMode: ->
			if this.publishMode == "publish"
				return "publish"
			else
				return "draft"

		publishChecked: ->
			if this.publishMode == "publish"
				return "checked"
			else
				return ""


	Template.tutorial.events
		"click button.delete": ->
			r = confirm("Delete this tutorial? This cannot be undone.")
			if r == true 
				Tutorials.remove this._id

	Template.tutorial.rendered = ->	
		$('.lazyYT').lazyYT()
		$( ".sortable" ).sortable
			handle: ".sorthandle"
			start: (event, ui ) ->
				$(this).addClass("sorting");
			stop: (event, ui ) ->
				$(this).removeClass("sorting");
				$(this).children(".step").each (i) ->
					Steps.update $(this).attr("id"),
						$set:  
							ordinal: i * 10
							updatedAt: new Date() # current time
						(error) -> 
							console.log error
						
		

	Template.upload.events
		"submit .update-icon": (event, target) ->
			file = event.target[0].files[0]
#			if (file)
#				Icons.insert(file, ction (err, fileObj) {

#			for file in files
#				console.log file
			return false
#				Images.insert(files[i], (err, fileObj) ->

	Template.step.helpers
		video_embedded: ->
			console.log("video-embedded-called")
			if this.video_url
				parseUrl = this.video_url.match(/(http|https):\/\/(?:www.)?(?:(vimeo).com\/(.*)|(youtube).com\/watch\?v=(.*?)$)/)
				if parseUrl
					if parseUrl[2] || parseUrl[3]
						vimeoID = parseUrl[3]
						embedUrl = '//player.vimeo.com/video/' + vimeoID
						return '<div class="lazyYT" data-vimeo-id="' + vimeoID + '"></div>'
					else
						youtubeID = parseUrl[5]
						embedUrl = '//www.youtube.com/embed/' + youtubeID
						return '<div class="lazyYT" data-youtube-id="' + youtubeID + '"></div>'

	Deps.autorun ->
		steps_dep.depend()
		$('.lazyYT').lazyYT()

	Template.step.events
		"click button.delete": ->
			r = confirm("Delete this step? This cannot be undone.")
			if r == true 
				Steps.remove this._id


	Template.step.events "submit .update-step": ->
		$(".step").find(".edit-form").hide('slide', { 'direction': 'right'}, 300);
		description = event.target.description.value
		video_url = event.target.video_url.value
		Steps.upsert this._id,
			$set:  
				tutorial_id: this.tutorial_id
				description: description
				video_url: video_url
				ordinal: 99999
				updatedAt: new Date() # current time
		if "new" in this
			event.target.description.value = ""
			event.target.video_url.value = ""
		steps_dep.changed()
		console.log "update-step"
		return false


	Template.step.rendered = ->
		button = this.find('.button');
		console.log(button);




	Template.sectiontree.helpers nodes: ->
		if(Meteor.user())
			Tutorials.find {},
				sort:
					createdAt: -1
		else
			console.log("fuck");
			Tutorials.find {'publishMode':'publish'},
				sort:
					createdAt: -1

	Template.sectiontree.rendered = ->
		if(!this._rendered)
			this._rendered = true;
			#template onload
		
	Template.node.helpers
		xpos: ->
			if(Meteor.user())
				this.draft_x * GRID_MULTIPLIER
			else
				this.x * GRID_MULTIPLIER
		ypos: ->
			if(Meteor.user())
				this.draft_y * GRID_MULTIPLIER
			else
				this.y * GRID_MULTIPLIER
		draftMode: ->
			nodes_dep.depend()
			that = this
			if this.draft_y != this.y or this.draft_x != this.x
				return "draft-node"
#				$(".node#" + this._id).addClass("draft-node")


	Template.body.events "click .button": ->
		targetForm = $(event.target).closest(".step, .tutorial").find(".edit-form").first()
			.toggle('slide', { 'direction': 'right'}, 300)
				

	Template.node.events "click": ->
		$(".tutorial").fadeOut(50);
		$(".tutorial#" + this._id).fadeIn(50);

	Template.node.events "click .change-dep": ->
		if(Meteor.user())
			unless Session.get("dep-mode") is "True"
				$("body").addClass "dep-mode"
				Session.set "dep-mode", "True"
				Session.set "dep-from", this._id
				Session.set "mouseX", this.draft_x * GRID_MULTIPLIER
				Session.set "mouseY", this.draft_y * GRID_MULTIPLIER
				$(".section-tree").bind "mousemove", (e) ->
					$(".section-tree").line Session.get('mouseX'),Session.get('mouseY'),e.pageX, e.pageY, {id: 'depline'}

			else
				$("body").removeClass "dep-mode"
				$(".section-tree").unbind "mousemove"
				$("#depline").remove()
				Session.set "dep-mode", "False"
				tut1_id = [ this._id, Session.get("dep-from") ].sort()[0]
				tut2_id = [ this._id, Session.get("dep-from") ].sort()[1]
				Session.set "dep-from", ""
				existingLinks = Links.find(
					tutorial1: tut1_id
					tutorial2: tut2_id
				).fetch()
				
				if existingLinks.length > 0
					console.log "removing dep"


					conns = jsPlumb.getConnections
						source:tut1_id
						target:tut2_id
					_.each conns, (c) ->
						jsPlumb.detach c
					
					_.each existingLinks, (d) ->
						Links.remove d._id

				else if tut1_id != tut2_id
					console.log "adding dep " + tut1_id + "-->" + tut2_id
					Links.insert
						tutorial1: tut1_id
						tutorial2: tut2_id
						createdAt: new Date() # current time
					nodes_dep.changed
					

	
	drawLinks = (from_id) ->
		_.each Links.find({tutorial1: from_id}).fetch(), (d) ->
			console.log d
			"""
			jsPlumb.connect
				source: $('#' + d.tutorial1)
				target: $('#' + d.tutorial2)
				anchor: [ "Left", "Right" ]
			"""



	Template.node.helpers
		nodeIcon: ->
			icon = Icons.findOne({tutorial_id:this._id})
			if(icon)
				imgurl = '/uploads/' + icon.filename
			else
				imgurl = DEFAULT_ICON
			return "<img src='" + imgurl + "'>"
				

				


	Template.node.rendered = ->
		console.log "node renderd"

#		drawLinks this.data._id

		if(Meteor.user())
			$(".node#" + this.data._id).draggable
				grid: [ GRID_MULTIPLIER, GRID_MULTIPLIER ] 
				stop: (event, ui) -> # fired when an item is dropped
					$("body").addClass "draft-mode"
					Session.set "draft-mode", "True"
					tut = Blaze.getData(ui.helper[0])
					$(".node#" + tut._id).addClass("draft-node")

					Tutorials.update tut._id,
						$set:
							draft_x: ui.position.left / GRID_MULTIPLIER
							draft_y: ui.position.top / GRID_MULTIPLIER

	Template.body.helpers
		allicons: ->
			return _.map(Icons.find({}).fetch(), (i) -> return i.filename;)



		

	Accounts.ui.config
		passwordSignupFields: "USERNAME_ONLY"


if Meteor.isServer
	Meteor.startup ->
		