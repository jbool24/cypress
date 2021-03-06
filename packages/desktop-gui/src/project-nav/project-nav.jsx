import React, { Component } from 'react'

import Browsers from './browsers'
import { Link, routes } from '../lib/routing'

export default class ProjectNav extends Component {
  render () {
    const project = this.props.project

    return (
      <nav className='navbar navbar-default navbar-fixed-top'>
        <div className='container-fluid'>
          <ul className='nav navbar-nav'>
            <li>
              <Link to={routes.specs(project)}>
                <i className='fa fa-code'></i>{' '}
                Tests
              </Link>
            </li>
            <li>
              <Link to={routes.runs(project)}>
                <i className='fa fa-database'></i>{' '}
                Runs
              </Link>
            </li>
            <li>
              <Link to={routes.settings(project)}>
                <i className='fa fa-cog'></i>{' '}
                Settings
              </Link>
            </li>
          </ul>
          <Browsers project={project} />
        </div>
      </nav>
    )
  }
}
