#!/bin/bash
# ----------------------------------------------------------------------------------------------
# Test
#
# Enjoy. (c) The Optino Project. GPLv2
# ----------------------------------------------------------------------------------------------
TESTINPUT=test/TestStakingFactory.js
TESTOUTPUT=results/TestStakingFactory.txt

echo "\$ npx hardhat test $TESTINPUT > $TESTOUTPUT" | tee $TESTOUTPUT

npx hardhat test $TESTINPUT | tee -a $TESTOUTPUT

# Strip out unnamed event parameters
# sed -i '' 's/(0:.*length__: [0-9]*, /(/g' $TESTOUTPUT
