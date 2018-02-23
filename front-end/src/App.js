import React, { Component } from 'react'
import { Route } from 'react-router-dom'

import Main from './Main'
import Profile from './Profile'

class App extends Component {
  render() {
    return (
      <main>
        <Route exact path='/' component={Main} />
        <Route exact path='/profile' component={Profile} />
      </main>
    )
  }
}

export default App
