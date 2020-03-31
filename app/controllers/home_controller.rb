class HomeController < ApplicationController
  def index
    params[:days] ||= 14
    params[:days] = [params[:days].to_i, 180].min
    params[:avg] ||= 'sma-60'
    params[:slowing] ||= 0
    params[:slowing] = [params[:slowing].to_i, 95].min

    population = 350000000

    if params[:avg][0..90] == 'sma'
      avg = :sma
    else
      avg = :ema
    end

    avgdays = params[:avg][4].to_i || 3

    response = HTTParty.get('https://covidtracking.com/api/us/daily')
    @data = JSON.parse(response.body)

    positive = 0
    newpositive = 0
    hospitalized = 0
    death = 0
    growthrate = 0
    growthrates = []

    @data.reverse.each_with_index do |row, i|
      row['date'] = DateTime.parse(row['dateChecked'])

      if i == 0
        row['newpositive'] = positive
      else
        row['newpositive'] = row['positive'] - positive

        # Use growth rate of new daily cases
        row['growthrate'] = ((row['newpositive'].to_f - newpositive) / newpositive * 100).round(2)
      end

      row['hospitalizedrate'] = (row['hospitalized'].to_f / row['positive'] * 100).round(2)
      row['deathrate'] = (row['death'].to_f / row['positive'] * 100).round(2)

      positive = row['positive']
      newpositive = row['newpositive']
      death = row['death']
      hospitalized = row['hospitalized']
      growthrate = row['growthrate']

      growthrates.shift if growthrates.count > avgdays

      growthrates << growthrate if growthrate

      row['growthratesma'] = growthrates.sma.round(2) if growthrates.count > 0
      row['growthrateema'] = growthrates.ema.round(2) if growthrates.count > 0
    end

    if avg == :sma
      growthrate = growthrates.sma.round(2)
    else
      growthrate = growthrates.ema.round(2)
    end

    hospitalizedrate = @data.first['hospitalizedrate']
    deathrate = @data.first['deathrate']

    ((@data.first['date'] + 1.day)..(@data.first['date'] + params[:days].days)).each do |date|
      newpositive = newpositive * (1 + growthrate / 100) * (1 - params[:slowing].to_f / 100)

      #positive += positive * (growthrate / 100) * (1 - params[:slowing].to_f / 100)
      positive += newpositive

      record = {
        'date' => date,
        'positive' => positive.round,
        'newpositive' => positive.round - @data.first['positive'],
        'hospitalized' => (positive * hospitalizedrate / 100).round,
        'hospitalizedrate' => hospitalizedrate,
        'death' => (positive * deathrate / 100).round,
        'deathrate' => deathrate,
        'growthrate' => growthrate
      }

      @data.insert(0, record)

      prev = @data.last

      if positive >= population / 2
        break
      end
    end

    gon.dates = []
    gon.newpositives = []
    gon.positives = []
    gon.colors = []

    @data.reverse.each do |r|
      gon.dates << r['date'].strftime('%Y-%m-%d')
      gon.newpositives << r['newpositive']
      gon.positives << r['positive']
      if r['growthrateema']
        gon.colors << 'rgba(133,133,133,0.2)'
      else
        gon.colors << 'rgba(0,120,120,0.2)'
      end
    end
  end
end
