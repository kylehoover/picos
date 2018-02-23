import React from 'react'

const TempListItem = ({ tempItem }) => {
  const textColor = tempItem.violation ? 'red-text' : 'green-text'
  const timestamp = new Date(tempItem.timestamp)
  const degreeSymbol = '\u00b0'

  return (
    <li id='temp-list-item'>
      <span className={`temp ${textColor}`}>
        {tempItem.temperature} {degreeSymbol}F
      </span>
      <span className='timestamp grey-text'>
        {timestamp.toLocaleString()}
      </span>
    </li>
  )
}

export default TempListItem