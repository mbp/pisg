# 2004-11-21 by coaster

alias me {
  if ($1) {
    .describe $active $1-
    echo $color(own) -qt $active ** $me $1-
  }
  else {
    echo $color(info) $active * /me: insufficient parameters
  }
}

on ^*:ACTION:*:*:{
  echo $color(action) -lt $iif($chan,$chan,$nick) ** $nick $1-
  haltdef
}
