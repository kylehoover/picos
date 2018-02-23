import axios from 'axios'

const api = axios.create({
  baseURL: 'http://35.185.50.186:8080',
  responseType: 'json'
})

const eci = 'XdAytbxgtbhFva14zzmFzv'
const skyCloud = `/sky/cloud/${eci}/`
const skyEvent = `/sky/event/${eci}/eci/`

export default {
  getInRangeTemps: () => api.get(skyCloud + 'temperature_store/inrange_temperatures'),
  getProfile: () => api.get(skyCloud + 'sensor_profile/profile'),
  getTemps: () => api.get(skyCloud + 'temperature_store/temperatures'),
  getViolations: () => api.get(skyCloud + 'temperature_store/threshold_violations'),
  updateProfile: (data) => api.post(skyEvent + 'sensor/profile_updated', data)
}