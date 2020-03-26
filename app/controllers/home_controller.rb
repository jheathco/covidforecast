class HomeController < ApplicationController
  def index
    response = HTTParty.get('https://covidtracking.com/api/us/daily')
    @data = JSON.parse(response.body)

    positive = 0
    hospitalized = 0
    death = 0
    growthrate = 0
    growthrates = []

    @data.reverse.each_with_index do |row, i|
      row['date'] = DateTime.new(row['date'].to_s[0..3].to_i, row['date'].to_s[4..5].to_i, row['date'].to_s[6..7].to_i)

      if i > 0
        row['growthrate'] = ((row['positive'].to_f - positive) / positive * 100).round(2)
        row['newpositive'] = row['positive'] - positive
      end

      positive = row['positive']
      death = row['death']
      hospitalized = row['hospitalized']
      growthrate = row['growthrate']

      growthrates.shift if growthrates.count > 3

      growthrates << growthrate if growthrate

      row['growthratesma'] = growthrates.sma.round(2) if growthrates.count > 0
      row['growthrateema'] = growthrates.ema.round(2) if growthrates.count > 0
    end

    growthrate = growthrates.ema.round(2)

    (@data.first['date']..(@data.first['date'] + 14.days)).each do |date|
      positive *= (100 + growthrate) / 100

      record = {
        'date' => date,
        'positive' => positive.round,
        'newpositive' => positive.round - @data.first['positive'],
        'hospitalized' => 50,
        'death' => 20,
        'growthrate' => growthrate
      }

      @data.insert(0, record)

      prev = @data.last
    end
  end
end
