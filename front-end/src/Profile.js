import React, { Component } from 'react'
import { Link } from 'react-router-dom'
import api from './api'

class Profile extends Component {
  constructor() {
    super()

    this.state = {
      name: '',
      location: '',
      threshold: 0,
      notification_number: '',
      saving: false
    }
  }

  componentDidMount() {
    api.getProfile()
      .then(resp => {
        this.setState({
          ...resp.data
        }, () => {
          window.Materialize.updateTextFields()
        })
      })
  }

  handleInputChange = (e) => {
    this.setState({
      [e.target.name]: e.target.value
    })
  }

  handleSubmit = (e) => {
    e.preventDefault()

    this.setState({
      saving: true
    })

    const data = {
      ...this.state,
      threshold: parseInt(this.state.threshold)
    }

    api.updateProfile(data)
      .then(resp => {
        this.setState({
          saving: false
        })
        window.Materialize.toast('Profile saved', 5000)
      })
      .catch(err => {
        console.log(err)
      })
  }

  render() {
    const formClassName = this.state.saving ? 'hide' : ''
    const spinnerClassName = this.state.saving ? '' : 'hide'

    return (
      <div id='profile'>
        <h2>Sensor Profile</h2>
        <div className={formClassName}>
          <Link to='/' id='back-btn' className='waves-effect waves-light btn cyan'>
            Back
          </Link>
          <form onSubmit={this.handleSubmit}>
            <div className='row'>
              <div className='input-field col s6'>
                <input name='name' type='text' value={this.state.name} onChange={this.handleInputChange} />
                <label htmlFor='name'>Name</label>
              </div>
              <div className='input-field col s6'>
                <input name='location' type='text' value={this.state.location} onChange={this.handleInputChange} />
                <label htmlFor='location'>Location</label>
              </div>
            </div>
            <div className='row'>
              <div className='input-field col s6'>
                <input name='threshold' type='number' value={this.state.threshold} onChange={this.handleInputChange} />
                <label htmlFor='threshold'>Temperature Threshold</label>
              </div>
              <div className='input-field col s6'>
                <input name='notification_number' type='text' value={this.state.notification_number} onChange={this.handleInputChange} />
                <label htmlFor='notification_number'>Notification Number</label>
              </div>
            </div>
            <div className='row'>
              <button className='waves-effect waves-light btn green' type='submit'>
                Save
              </button>
            </div>
          </form>
        </div>
        <div id='spinner' className={spinnerClassName}>
          <div className='preloader-wrapper big active'>
            <div className='spinner-layer spinner-blue-only'>
              <div className='circle-clipper left'>
                <div className='circle' />
              </div><div className='gap-patch'>
              <div className='circle' />
            </div><div className='circle-clipper right'>
              <div className='circle' />
            </div>
            </div>
          </div>
        </div>
      </div>
    )
  }
}

export default Profile