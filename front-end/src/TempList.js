import React from 'react'
import TempListItem from './TempListItem'

const TempList = ({ temps, max }) => {
  if (max) {
    temps = temps.slice(0, max)
  }

  return (
    <ul>
      {temps.map((temp, index) => <TempListItem tempItem={temp} key={index} />)}
    </ul>
  )
}

export default TempList