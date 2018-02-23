import React, { Component } from 'react'
import { Link } from 'react-router-dom'
import api from './api'

import CurrentTemp from './CurrentTemp'
import TempList from './TempList'

class Main extends Component {
  constructor() {
    super()

    this.state = {
      currentTemp: undefined,
      temps: []
    }
  }

  addTemps = (temps) => {
    this.setState((prevState) => {
      const newTemps = prevState.temps.concat(temps).sort(this.compareTemps)
      const currentTemp = newTemps.length ? newTemps[0] : undefined

      return {
        currentTemp: currentTemp,
        temps: newTemps
      }
    })
  }

  compareTemps = (a, b) => {
    if (a.timestamp < b.timestamp)
      return 1
    if (a.timestamp > b.timestamp)
      return -1
    return 0
  }

  componentDidMount() {
    api.getInRangeTemps()
      .then(resp => {
        this.addTemps(resp.data)
      })
      .catch(err => {
        console.log(err)
      })

    api.getViolations()
      .then(resp => {
        const violations = resp.data.map(temp => ({...temp, violation: true}))
        this.addTemps(violations)
      })
      .catch(err => {
        console.log(err)
      })
  }

  render() {
    return (
      <div>
        <CurrentTemp tempItem={this.state.currentTemp} />
        <Link to='/profile' id='sens-prof-btn' className='waves-effect waves-light btn cyan'>
          Sensor Profile
        </Link>
        <header>Recent Readings</header>
        <TempList temps={this.state.temps} max={20} />
      </div>
    )
  }
}

export default Main
