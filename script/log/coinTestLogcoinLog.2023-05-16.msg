Error in setDT(result) : All elements in argument 'x' to 'setDT' must be of same length, but the profile of input lengths (length:frequency) is: [2:1, 0:2] The first entry with fewer than 2 entries is 2 
Traceback: 
[1] "4: stop(\"All elements in argument 'x' to 'setDT' must be of same length, but the profile of input lengths (length:frequency) is: \", "
[2] "       brackify(sprintf(\"%s:%d\", names(tbl), tbl)), \"\\nThe first entry with fewer than \", "                                       
[3] "       n_range[2L], \" entries is \", which.max(n < n_range[2L]))"                                                                     
[4] "3: setDT(result) at #6"                                                                                                                
[5] "2: getCurrentUpbitAccountInfo() at #7"                                                                                                 
[6] "1: getCurrentBalance()"                                                                                                                

