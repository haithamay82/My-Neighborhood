import turtle

# create screen and turtle
t = turtle.Turtle()
t.speed(2)                # drawing speed
t.color("red")            # stroke color
t.pensize(3)              # line thickness

# draw circle
t.begin_fill()            # optional (if you want filled circle)
t.circle(100)             # radius = 100
t.end_fill()              # optional

turtle.done()
