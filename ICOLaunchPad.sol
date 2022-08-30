// /SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
interface IERC201{
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount) external returns (bool);
}
interface IUniswapV2Router02 {
     function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);

     function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
}
interface IUniswapV2Factory{
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
contract ICOLaunchpad is ReentrancyGuard{
    address private constant FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address private constant ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant WETH = 0xc778417E063141139Fce010982780140Aa0cD5Ab;

    using SafeMath for uint;
    address private manager;

    event lProject(address _projectAdd,uint noTokens,uint _rate,uint sD,uint eD);
    event calculate(uint );
    event buyT (address buyer,uint numberofTokens);
    event refundevent(address paddress,address baddress,uint amount);
    event fundtransferevent(address paddress,address tokenOwneraddress,uint amount,uint remainingToken);
    event ALE(uint,uint,uint);
    event RLE(uint,uint);

    struct Project{
        address projectAdd;
        address payable owner;
        uint startDate;
        uint endDate;
        uint listDate;
        uint targetAmount;
        uint noTokens;
        uint rate;
        uint amountGenerated;
    }
    struct buyerData{
        uint amount;
        uint tokens;
        uint date ;
    }
    mapping(address => Project) public projects;
    Project[] public parr2;
    mapping(address => mapping (address=>buyerData)) public buyers;
    constructor(){
        manager = msg.sender;
    }
     modifier onlyManger{
        require(manager == msg.sender,"Only authorize manager access it");
        _;
    }
    modifier lock1(address _projectAdd){
        Project storage p = projects[_projectAdd];
        uint timePeriod = 60 + p.endDate;
        require(block.timestamp > timePeriod);
        _;
    }
    function listProject(address _tokenAdd,uint _noTokens,uint _rate,uint sD,uint eD) external {
        Project  storage newP = projects[_tokenAdd];
        newP.projectAdd = _tokenAdd;
        newP.owner = payable(msg.sender);
        newP.listDate = block.timestamp;
        newP.noTokens = _noTokens;
        newP.startDate = sD;
        newP.endDate = eD;
        newP.rate = _rate;
        parr2.push(newP);
        IERC201(_tokenAdd).transferFrom(msg.sender,address(this),_noTokens);
        emit lProject (_tokenAdd,_noTokens, _rate, sD, eD);
    }
    function caculate(uint amountTokens,address _projectAdd) external  {
         Project  storage p = projects[_projectAdd];
        uint amount = amountTokens;
        uint eth = amount.mul(p.rate);
        emit calculate (eth);
    }
    function BuyToken(address _projectAdd) external payable{
        Project  storage p = projects[_projectAdd];
        require(block.timestamp > p.startDate,"Tokens Selling not started");
        require(block.timestamp < p.endDate,"Tokens selling ends");
        address buyer = msg.sender;
        uint amount =msg.value;
        p.amountGenerated += amount;
        buyers[_projectAdd][msg.sender].amount = amount;
        uint noTokens = amount.div(p.rate);
        buyers[_projectAdd][buyer].tokens= noTokens;
        buyers[_projectAdd][buyer].date = block.timestamp;
        IERC201(_projectAdd).transfer(buyer,noTokens);
        emit buyT (buyer,noTokens);
    }
    function refund(address _projectAdd,address buyeradd) external{
        Project  storage p = projects[_projectAdd];
        require(block.timestamp > p.startDate,"Refund not started");
        require(block.timestamp < p.endDate,"Refund times ends");
        buyerData storage b = buyers[_projectAdd][msg.sender];
        require( b.amount > 0,"You not purchase the tokens");
        address payable buyer = payable(msg.sender);
        IERC201(_projectAdd).transferFrom(msg.sender,address(this),b.tokens);
        buyer.transfer(b.amount);
        b.amount=0;
        emit refundevent(_projectAdd,buyeradd,b.amount);
    }
    function fundTransfer(address _projectAdd) external lock1(_projectAdd){
        Project storage p = projects[_projectAdd];
        require(p.owner == msg.sender,"only owner of token transfer");
        uint amount = p.amountGenerated;
        p.amountGenerated = 0;
        p.owner.transfer(amount);
        IERC201(_projectAdd).transfer(msg.sender,IERC201(_projectAdd).balanceOf(address(this)));
        uint remainingT = IERC201(_projectAdd).balanceOf(address(this));
        emit fundtransferevent(_projectAdd,msg.sender,p.amountGenerated,remainingT);
    }
   function investETH(
        address token,
        uint amountTokenDesired
    ) external payable onlyManger{
    IERC20(token).transferFrom(msg.sender,address(this),amountTokenDesired);
    IERC20(token).approve(ROUTER, amountTokenDesired);
    (uint amountToken, uint amountETH, uint liquidity)=
    IUniswapV2Router02(ROUTER).addLiquidityETH{value: address(this).balance}(token,
    amountTokenDesired,
    1,
    1,
    address(this),
    block.timestamp);
    emit ALE(amountToken,amountETH,liquidity);
    }

    function getAmountInMin(address _token, uint256 _amountIn)internal view returns(uint[] memory){
        address[] memory path;
        path = new address[](2);
        path[0]=_token;
        path[1]=WETH;
        uint256[] memory amountInMins = IUniswapV2Router02(ROUTER).getAmountsIn(_amountIn, path);
        return amountInMins;
    }

    function getAmountOutMin(address _token, uint256 _amountOut) internal view returns(uint[] memory){
        address[] memory path;
        path = new address[](2);
        path[0]=_token;
        path[1]=WETH;
        uint256[] memory amountOutMins = IUniswapV2Router02(ROUTER).getAmountsOut(_amountOut, path);
        return amountOutMins;
    }
    receive() external payable {
    }
    function getbackETH(address token)external payable onlyManger{
        address pair = IUniswapV2Factory(FACTORY).getPair(token, WETH);
        uint liquidity= IERC20(pair).balanceOf(address(this));
        IERC20(pair).approve(ROUTER, liquidity);
        uint256[] memory amountOutMins = getAmountOutMin(token,liquidity);
        (uint amountToken, uint amountETH) =
        IUniswapV2Router02(ROUTER).removeLiquidityETH(
          token,
          liquidity,
          amountOutMins[0],
          amountOutMins[1],
          address(this),
          block.timestamp
        );
        emit RLE(amountToken,amountETH);
  }
    function cbalance(address add)external view returns(uint){
        return add.balance;
    }
}
