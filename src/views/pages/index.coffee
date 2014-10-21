{ _, Ractive, async } = require '../../modules/vendor.coffee'

Hero     = require '../hero.coffee'
Projects = require '../tables/projects.coffee'

projects   = require '../../models/projects.coffee'
system     = require '../../models/system.coffee'
milestones = require '../../modules/github/milestones.coffee'
issues     = require '../../modules/github/issues.coffee'
mediator   = require '../../modules/mediator.coffee'

module.exports = Ractive.extend

  'name': 'views/pages/index'

  'template': require '../../templates/pages/index.html'

  'components': { Hero, Projects }

  'data':
    'projects': projects
    'ready': no

  'adapt': [ Ractive.adaptors.Ractive ]

  onrender: ->
    document.title = 'Burnchart: GitHub Burndown Chart as a Service'

    # Quit if we have no projects.
    return @set('ready', yes) unless projects.list.length

    done = do system.async

    # For all projects.
    async.map projects.data.list, (project, cb) ->
      # Fetch their milestones.
      milestones.fetchAll project, (err, list) ->
        # Save the error if project does not exist.
        if err
          projects.saveError project, err
          return do cb

        # Now add in the issues.
        async.each list, (milestone, cb) ->
          # Do we have this milestone already?
          return cb null if _.find project.milestones, ({ number }) ->
            milestone.number is number
          
          # OK fetch all the issues for this milestone then.
          issues.fetchAll
            'owner': project.owner
            'name': project.name
            'milestone': milestone.number
          , (err, obj) ->
            # Save any errors on the project.
            if err
              projects.saveError project, err
              return do cb

            # Add in the issues to the milestone.
            _.extend milestone, { 'issues': obj }
            # Save the milestone.
            projects.addMilestone project, milestone
            # Done
            do cb
        
        , cb

    , =>
      do done
      @set 'ready', yes