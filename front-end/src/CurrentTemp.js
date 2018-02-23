import React from 'react'

const CurrentTemp = ({ tempItem }) => {
  let content

  if (tempItem) {
    const textColor = tempItem.violation ? 'red-text' : 'green-text'
    const degreeSymbol = '\u00b0'

    content =
      <div>
        <span className='temp-text'>
          Current temperature:
        </span>
        <span className={`temp ${textColor}`}>
          {tempItem.temperature} {degreeSymbol}F
        </span>
      </div>
  } else {
    content =
      <div className='temp-text'>
        No current temperature reading
      </div>
  }

  return (
    <div id='current-temp'>
      {content}
    </div>
  )
}

export default CurrentTemp