#define ZERO_TO_ONE(dvarArg) (milliseconds() - dvarInt(ui_time_marker) - dvarInt(spawnedTime) + dvarInt("openMenuTime" + dvarArg))
#define ANIMATE(dvarArg,timeArg) max( min( ZERO_TO_ONE(dvarArg) / (timeArg*1000) , 1 ) , 0 )
#define ANIMATE_VISIBLE(dvarArg,visTimeArg)  int(ZERO_TO_ONE(dvarArg) < (visTimeArg*1000))
