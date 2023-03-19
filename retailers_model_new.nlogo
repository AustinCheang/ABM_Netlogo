;run market share allocation
extensions [
  py
]

globals [
  market-shares-list
  current-intersection

  grid-x-inc               ; the amount of patches in between two roads in the x direction
  grid-y-inc               ; the amount of patches in between two roads in the y direction

  intersections ; agentset containing the patches that are intersections
  roads         ; agentset containing the patches that are roads

  grid-list
  global-grid-list
]

breed [customers customer]
breed [retailers retailer]

customers-own [
  preferred-shop
  buying-frequency
  budget
]
retailers-own [
  price
  market-share
  evaluation-period
  price-change
  previous-market-share
  cumulative-profit
  previous-cumulative-profit
  quantity-sold
  old-price
]
patches-own [
  my-row          ; the row of the intersection counting from the upper left corner of the
                  ; world.  -1 for non-intersection patches.
  my-column       ; the column of the intersection counting from the upper left corner of the
                  ; world.  -1 for non-intersection patches.
]


; #################################################################### Set UP ############################################################
to setup
  clear-all
  py:setup py:python

; Set up the world
  setup-globals
  setup-patches
  create-grid-dict

; Set up the agents
  setup-retailers
  assign-retailers-locations

  setup-customers

  ; Initial Setup for customers' preferences
  update-customers-preferences


  ; Initial market shares distribution
  update-market-shares


;  py:set "retailers" retailers
;  py:set "customers" customers

  display-labels
  display-chosen-shop-labels

  reset-ticks
end

to setup-globals
  set grid-x-inc world-width / 7
  set grid-y-inc world-height / 7
end

; Make the patches have appropriate colors, set up the roads and intersections agentsets,
to setup-patches
  ; initialize the patch-owned variables and color the patches to a base-color
  ask patches
  [
    set my-row -1
    set my-column -1
    set pcolor 35
  ]

  ; initialize the global variables that hold patch agentsets
  set roads patches with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) or
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]
  set intersections roads with
    [(floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) = 0) and
    (floor((pycor + max-pycor) mod grid-y-inc) = 0)]

  ask roads [ set pcolor 7 ]
  setup-intersections
end

; Give the intersections appropriate values for the intersection?, my-row, and my-column patch variables.
to setup-intersections
  ask intersections
  [
    set my-row floor((pycor + max-pycor) / grid-y-inc)
    set my-column floor((pxcor + max-pxcor) / grid-x-inc)
  ]
end

to setup-customers
  create-customers initial-number-customers  ; create customers, then initialize their variables
  [
    set shape "person"
    set size 1  ; easier to see
    setxy random-xcor random-ycor
    ifelse randomise-buying-frequency? [
      set buying-frequency random ( set-buying-frequency - 1) + 1
    ] [
      set buying-frequency set-buying-frequency
    ]
    ifelse randomise-budget?[
      let randn random 31 + 140
      set budget (unit-cost * randn / 100)
    ] [
      set budget (unit-cost * 1.6)
    ]
    show (word "budget: " budget)
  ]

end

to setup-retailers
  if experiment = "2-retailer-even-space" [
    set initial-number-retailers 2
  ]
  if experiment = "3-retailer-even-space" [
    set initial-number-retailers 3
  ]
  if experiment = "4-retailer-even-space" [
    set initial-number-retailers 4
  ]

  create-retailers initial-number-retailers ; Initialise the retailers agents
  [
    set shape "house"
    set color random 140 + 56 ; *** TODO: change the color codes
    set size 2.5  ; easier to see
    set price ( random-float ( 0.5 * unit-cost ) +  unit-cost )

    ifelse randomise-evaluation-period? [
      set evaluation-period random (set-evaluation-period-range - 5 ) + 5
    ] [
      set evaluation-period set-evaluation-period-range
    ]

    ifelse randomise-buying-frequency? [
      set set-buying-frequency random (set-evaluation-period-range - 1 ) + 1
    ] [
      set buying-frequency set-buying-frequency
    ]

    output-print ( word "Retailer: " WHO )
    output-print ( word "Inital Price: " price)
    output-print ( word "Evaluation Period: " evaluation-period)
    output-print ( " " )

    set quantity-sold 0
    set previous-cumulative-profit 1
  ]
end

to assign-retailers-locations
  py:set "grid_list_all" grid-list
  if experiment = "Customised" [
    ask retailers [
    let coordinates assign-locations
    set xcor item 0 coordinates
    set ycor item 1 coordinates
  ]
  ]
   if experiment = "2-retailer-even-space" [
    (py:run
      "available_locations = [22, 26]"
    )
    ask retailers [
    let retail-cor item 1 py:runresult("grid_list_all[available_locations.pop()]")
    show (retail-cor)
    set xcor item 0 retail-cor
    set ycor item 1 retail-cor
      ]
  ]
  if experiment = "3-retailer-even-space" [
    (py:run
      "available_locations = [22, 12, 40]"
     )
    ask retailers [
    let retail-cor item 1 py:runresult("grid_list_all[available_locations.pop()]")
    show (retail-cor)
    set xcor item 0 retail-cor
    set ycor item 1 retail-cor
      ]

   ]
  if experiment = "4-retailer-even-space" [
    (py:run
      "available_locations = [8, 12, 36, 40]"
     )
    ask retailers [
    let retail-cor item 1 py:runresult("grid_list_all[available_locations.pop()]")
    show (retail-cor)
    set xcor item 0 retail-cor
    set ycor item 1 retail-cor
      ]
  ]
end

to-report assign-locations
      py:set "grid_list_dict" grid-list
      (py:run
      "import random"
      "grid_list_dict = my_dict = {item[0]: item[1] for item in grid_list_dict}"
      "grid_id = random.randint(0, 48)"
;      "print(f'out grid_id: {grid_id}')"
      "while str(grid_id) not in grid_list_dict:"
      "    grid_id = random.randint(0, 48)"
;      "    print(f'duplicated grid_id: {grid_id}')"
      "grid_id = str(grid_id)"
      "x, y = grid_list_dict[grid_id]"
      "del grid_list_dict[grid_id]"
      )
  set grid-list py:runresult("grid_list_dict")
  report py:runresult("[x, y]")
end

to create-grid-dict
  (py:run
    "grid_list = {}"
    "counter = 0" ; keep track of all the grids in the map
    "for i in range(7):"
    "    for j in range(7):"
    "        grid_list[counter] = (-16 + i * 5 + 0.5, 16 - j *  5 - 0.5)" ; track the grid centre x, y coordinates
    "        counter += 1"
    )
    set grid-list py:runresult("grid_list")
    set global-grid-list py:runresult("grid_list")
end


; ############################################################### GO  #######################################################################

to go
  record-previous-profit
  update-customers-preferences
  buy ; check if customers need to buy
  update-market-shares
  evaluate-pricing-strategy


;  show (word "market-shares: " market-shares-list)
  update-customers-preference
  tick
  if ticks = set-run-day [ stop ]
end

; ############################################################ Labels and Switches ############################################################

to display-labels
  ask retailers [
    set label ""
  ]
  if show-shop-id? [
    ask retailers [
      set label WHO
      set label-color 2
    ]
  ]

end

to display-chosen-shop-labels
  ask customers [ set label "" ]
  if show-chosen-shop? [
    ask customers [
      set label preferred-shop
      set label-color black
    ]
  ]
end

to update-customers-preference
  ask customers [
    set label preferred-shop
    set label-color black
  ]
end

; ########################################################### Functions #########################################################################
to record-previous-profit
  ask retailers [
    set previous-cumulative-profit cumulative-profit
  ]
end

to update-customers-preferences
  ask customers [
    set preferred-shop calculate-weighted-preference XCOR YCOR WHO
  ]
end

to-report calculate-weighted-preference [ _XCOR _YCOR _WHO ]
  py:set "_WHO" _WHO
  py:set "retailers" retailers
  py:set "XCOR" _XCOR
  py:set "YCOR" _YCOR
  py:set "dist_fraction" distance-fraction
  py:set "price_fraction" price-fraction
  py:set "unit_cost" unit-cost

  ; Get the highest price of the retailers
  (py:run
    "import math"
    "from random import choice"

    ; Calculate weighted function
    "choices = {}"
    "for retailer in retailers:"
    "    distance = math.sqrt((XCOR - retailer['XCOR']) ** 2 + (YCOR - retailer['YCOR']) ** 2)"
    "    fractional_price = (retailer['PRICE']-unit_cost)/ (100- unit_cost)"
    "    fractional_distance=distance/34"
    "    weighted_sum = dist_fraction * fractional_distance + price_fraction * fractional_price"
    "    choices[retailer['WHO']] = weighted_sum"

    "min_list=[]"
    "min_weighted_sum=min(choices.values())"
    "for m , n in choices.items():"
    "    if n == min_weighted_sum:"
    "        min_list.append(m)"

    "final_choice = choice(min_list)"
  )
  report py:runresult "final_choice"
end

; Calculate distance helper function
to-report calculate-distance [ _XCOR _YCOR _WHO]
  py:set "_WHO" _WHO
  py:set "retailers" retailers
  py:set "XCOR" _XCOR
  py:set "YCOR" _YCOR

  (py:run
    "import math"
    "distances = {}"
    "current_nearest = float('inf')"
    "for retailer in retailers:"
    "    distance = math.sqrt((XCOR - retailer['XCOR']) ** 2 + (YCOR - retailer['YCOR']) ** 2)"
    "    distances[retailer['WHO']] = distance"
  )

  report py:runresult "distances"
end

; Calculate market-shares
to update-market-shares
  py:set "num_retailers" count retailers
  py:set "reatilers" retailers
  py:set "customers" customers
  (py:run
    "from collections import defaultdict"
    "market_shares_count = defaultdict(int)"
    "for customer in customers:"
    "    if 'PREFERRED-SHOP' in customer:"
    "        market_shares_count[customer['PREFERRED-SHOP']] += 1"
   )
  let markets-shares-count py:runresult "market_shares_count"
  set market-shares-list markets-shares-count

  ask retailers [
    set previous-market-share market-share
    set market-share get-update-market-share who markets-shares-count
  ]
end

; Update retailer's market shares by retailer ID
to-report get-update-market-share [ retailer_id market-shares-count ]
  py:set "market_shares_count" market-shares-count
  py:set "retailer_id" retailer_id
  (py:run
    "count = 0"
    "for market_share in market_shares_count:"
    "    if int(market_share[0]) == int(retailer_id):"
    "        count = market_share[1]"
    "        break"
    )
   report py:runresult "count"
end

; Update retailer's pricing strategy by different critieria
to evaluate-pricing-strategy
  ask retailers [
    if ticks mod evaluation-period = 0 [
      ; get maximum market share
      py:set "market_shares_list" market-shares-list
      py:set "total_customers" initial-number-customers
      (py:run
        "max_market_share = total_customers"
        "if len(market_shares_list) > 0:"
        "    max_market_share = max(x[1] for x in market_shares_list)"
        "print('max_market_share: ', max_market_share)"
      )

      ifelse (market-share = py:runresult "max_market_share") and (market-share >= previous-market-share) and (cumulative-profit > previous-cumulative-profit)
      [
        set price-change random-float 1
        set price (price + price-change)
      ]
      [
        set old-price price
        set price-change random-float 2
        set price unit-cost
        while [price + price-change < old-price]
        [
          ;        show (word "price-change: " price-change)
          set price (price + price-change)
          set price-change random-float 0.5
        ]
      ]
    ]
    show (market-shares-list)
    show price
  ]

end

to buy
  ask customers [
    let preferr_shop preferred-shop
    let customer-budget budget
    if ticks mod (buying-frequency + 1) = 0 [
      ask retailers [
        if WHO = preferr_shop [
          ifelse customer-budget >= price
          [
            set quantity-sold ( quantity-sold + 1)
            set cumulative-profit (cumulative-profit + price - unit-cost)
          ]
          [
            set preferr_shop nobody
          ]
        ]
      ]
      set preferred-shop preferr_shop
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
343
479
829
966
-1
-1
13.66
1
10
1
1
1
0
1
1
1
-17
17
-17
17
0
0
1
ticks
30.0

BUTTON
59
95
164
129
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
341
92
566
125
initial-number-customers
initial-number-customers
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
341
184
568
217
unit-cost
unit-cost
20
50
29.0
1
1
NIL
HORIZONTAL

SWITCH
60
185
287
218
show-shop-id?
show-shop-id?
0
1
-1000

PLOT
896
335
1672
551
Price
Day
Price $
0.0
10.0
0.0
10.0
true
true
"" "ask retailers [\n  create-temporary-plot-pen (word who)\n  set-plot-pen-color color\n  plotxy ticks price\n]"
PENS
"Unit Cost" 1.0 0 -2674135 true "" "plotxy ticks unit-cost"

BUTTON
182
94
286
128
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
602
92
830
125
distance-fraction
distance-fraction
0
10
0.8
0.2
1
NIL
HORIZONTAL

SLIDER
602
140
831
173
price-fraction
price-fraction
0
10
3.6
0.2
1
NIL
HORIZONTAL

SWITCH
60
140
288
173
show-chosen-shop?
show-chosen-shop?
0
1
-1000

PLOT
894
90
1670
306
plot market share
Day
MarketShare %
0.0
10.0
0.0
1.0
true
true
"" "ask retailers [\n    create-temporary-plot-pen (word who)\n    set-plot-pen-color color\n    let market-share-percent (market-share / count customers)\n    plotxy ticks market-share-percent\n    \n]"
PENS
"Balanced Market" 1.0 0 -2674135 true "" "plotxy ticks (1 / count retailers)"

SWITCH
596
286
825
319
randomise-buying-frequency?
randomise-buying-frequency?
0
1
-1000

SLIDER
336
330
563
363
set-evaluation-period-range
set-evaluation-period-range
5
30
15.0
1
1
NIL
HORIZONTAL

SWITCH
336
286
562
319
randomise-evaluation-period?
randomise-evaluation-period?
0
1
-1000

OUTPUT
60
235
287
501
13

PLOT
895
579
1671
795
Cumulative Profit
Day
Profit $
0.0
10.0
0.0
10.0
true
true
"" "ask retailers [\n    create-temporary-plot-pen (word who)\n    set-plot-pen-color color\n    plotxy ticks cumulative-profit\n]"
PENS

TEXTBOX
473
252
724
355
Advanced Parameters
4
0.0
1

TEXTBOX
143
58
311
86
Set Up
4
0.0
1

SLIDER
595
329
828
364
set-buying-frequency
set-buying-frequency
1
7
6.0
1
1
NIL
HORIZONTAL

TEXTBOX
1244
60
1412
88
Results
4
0.0
1

TEXTBOX
546
445
714
473
Game
4
0.0
1

SLIDER
602
185
831
218
set-run-day
set-run-day
0
5000
2200.0
50
1
NIL
HORIZONTAL

CHOOSER
595
376
828
422
Experiment
Experiment
"Customised" "2-retailer-even-space" "3-retailer-even-space" "4-retailer-even-space"
2

PLOT
59
602
285
762
Buying-Frequency Distribution
Buying-Frequency
#
0.0
7.0
0.0
10.0
true
false
"" ""
PENS
"buying-freq" 1.0 1 -14070903 true "" "set-plot-y-range 0 7\nhistogram [buying-frequency] of customers"

TEXTBOX
785
15
1350
61
Base Model
15
0.0
1

SWITCH
338
376
564
411
randomise-budget?
randomise-budget?
0
1
-1000

SLIDER
341
140
565
173
initial-number-retailers
initial-number-retailers
1
10
3.0
1
1
NIL
HORIZONTAL

TEXTBOX
532
56
708
104
Parameters\n
4
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
