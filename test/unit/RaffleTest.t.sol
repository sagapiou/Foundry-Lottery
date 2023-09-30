// SPDX-License-Identifier: MIT

import {console, Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../mocks/VRFCoordinatorV2Mock.sol";

pragma solidity 0.8.19;

contract RaffleTest is Test {
    //** Events redefined here for the testing part */
    event EnteredRaffle(address indexed player);
    
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;
    uint256 deployerKey;

    address public PLAYER = makeAddr("saga");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            subscriptionId,
            callBackGasLimit,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitialisesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /////////////////////////
    // enterRaffle         //
    /////////////////////////

    function testRaffleRevertsWHenYouDontPayEnought() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEvent() public {
        vm.prank(PLAYER);
        // this line declares that the next event that we emit below has an indexed parameter in the first input variable 
        // and after that we run the process that emits it. We need to redefine the event at the top. 
        // the event is emitted by the function enterRaffle so we run that and the expect emit tests this
        vm.expectEmit(true,false,false,false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCanEnterWhenRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // to go ahead in time and blocks there are 2 chats. vm.warp and vm.roll
        vm.warp(block.timestamp+interval+1);
        // below is not needed but it is good to change the block
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /////////////////////////
    // checkUpkeep         //
    /////////////////////////

    function testCheckUpKeepReturnFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnFalseIfItRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        
        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        
        //Act 
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert 
        assertEq(upKeepNeeded, false);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreGood() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);

        //Act 
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        //Assert 
        assertEq(upKeepNeeded, true);
    }


    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTRue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);

        //Act //Assert
        // in foundry there is no opposite to expectRevert so if we just right a fuction that works the test will pass 
        raffle.performUpkeep("");
    }

     function testPerformUpKeepDoesNotRunIfCheckUpKeepIsFalse() public {
        //Arrange
        //vm.prank(PLAYER);
        //raffle.enterRaffle{value: entranceFee}();
        uint256 currentBalance= 0;
        uint256 numPlayers=0;
        Raffle.RaffleState rState = raffle.getRaffleState();  //OPEN

        // No block roll and warp

        //Act //Assert with a custom error revertion
        vm.expectRevert( abi.encodeWithSelector(Raffle.Raffle__upkeepNotNeeded.selector,currentBalance, numPlayers,rState));
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAntTimePassed() {
       vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAntTimePassed {
        // Arrange

        // Act  
        // vm.recordLogs(); records all events emitted into a Log array
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //for (uint256 i=1; i<requestId.length;i++) {
        //    console.log("Events Emitted : ", i);
        //    for (uint256 j; i < entries[i].topics.length ;j++) {
        //        console.log("Topic Emitted : ", j, " - ", string(abi.encodePacked(entries[i].topics[j])) );
        //    }
        //}

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint(raffleState) == 1); // 0 = open, 1 = calculating
    }


     /////////////////////////
    // fulfillRandomWords //
    ////////////////////////


    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // fuzz test. we pass a variable to our test function and foundry will try a series of tests 
    // we can see under forget test the number runs that were made e.g. run 256 times (runs: 256, μ: 78383, ~: 78383)
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEnteredAntTimePassed skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        // vm.mockCall could be used here...
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

        
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAntTimePassed
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}


 