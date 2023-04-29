/* eslint-disable no-unused-vars */
import { constants, utils } from "ethers";
import { ethers, upgrades } from "hardhat";
import { getMaxListeners } from "process";

async function deployAll() {
  const [deployer] = await ethers.getSigners();
  console.log("deployer", deployer.address);
  // polygon
  // const trustedForwarder = "0xf0511f123164602042ab2bCF02111fA5D3Fe97CD";
  // const trustedForwarderSelf = "0x5D5279793144210fE34b67C2bCd767Ecba24334D";
  // fantom
  const trustedForwarder = "0x64CD353384109423a966dCd3Aa30D884C9b2E057";
  let trustedForwarderSelf = "";

  const trustedF = await ethers.getContractFactory("MinimalForwarder2");
  const forwarderContract = await trustedF.deploy();
  await forwarderContract.deployed();
  trustedForwarderSelf = forwarderContract.address;
console.log('Trusted Forwarder Self: ', trustedForwarderSelf);

  const WalletRegistry = await ethers.getContractFactory("WalletRegistry");

  const walletRegistry = await upgrades.deployProxy(
    WalletRegistry,
    [trustedForwarderSelf],
    {
      initializer: "__walletRegistry_init",
    }
  );

  await walletRegistry.deployed();

  console.log("walletRegistry deployed to:", walletRegistry.address);
  const SubscriptionModule = await ethers.getContractFactory("SubscriptionModule");

  const subscriptionModule = await upgrades.deployProxy(
    SubscriptionModule,
    [2000, 3600 * 24 * 30, trustedForwarderSelf, walletRegistry.address],
    {
      initializer: "__subscription_init",
    }
  );

  await subscriptionModule.deployed();

  console.log("subscriptionModule deployed to:", subscriptionModule.address);

  // deploy gasrestriction
  const GasRestrictor = await ethers.getContractFactory("GasRestrictor");
  const gasRestrictor = await upgrades.deployProxy(
    GasRestrictor,
    [
      subscriptionModule.address,
      ethers.utils.parseEther("5"),
      trustedForwarderSelf,
    ],
    {
      initializer: "init_Gasless_Restrictor",
    }
  );
  await gasRestrictor.deployed();

  console.log("gasRestrictor Address", gasRestrictor.address);

  // deploy gamification
  const Gamification = await ethers.getContractFactory("Gamification");

  const gamification = await upgrades.deployProxy(
    Gamification,
    [subscriptionModule.address, trustedForwarderSelf, gasRestrictor.address],
    {
      initializer: "init_Gamification",
    }
  );
  await gamification.deployed();

  console.log("gamification Address", gamification.address);

  const txn = await subscriptionModule.addGasRestrictorAndGamification(
    gasRestrictor.address,
    gamification.address
  );
  await txn.wait();
  const txn55 = await walletRegistry.addGasRestrictorAndGamification(
    gasRestrictor.address,
    gamification.address
  );
  await txn55.wait();

  // const MessagingUpgradeable = await ethers.getContractFactory(
  //   "MessagingUpgradeable"
  // );

  // const dappId =
  //   "0x0000000000000000000000000000000000000000000000000000000000000000";
  // const ufarmTokenAddress = "0xA7305Ae84519fF8Be02484CdA45834C4E7D13Dd6";
  // const spamTokensAdmin = "0x2fe4540239f6b01addf75E15239FBeFA226eB6BE";

  // const messagingUpgradeable = await upgrades.deployProxy(
  //   MessagingUpgradeable,
  //   [
  //     dappId,
  //     subscriptionModule.address,
  //     gasRestrictor.address,
  //     ufarmTokenAddress,
  //     spamTokensAdmin,
  //     trustedForwarderSelf,
  //   ],
  //   {
  //     initializer: "__Messaging_init",
  //   }
  // );

  // await messagingUpgradeable.deployed();

  // console.log(
  //   "MessagingUpgradeable deployed to:",
  //   messagingUpgradeable.address
  // );

  // await addNewDapp();
  const txn2 = await gasRestrictor.addDapp(gamification.address);
  await txn2.wait();
  console.log("added gamification in gasrestrictor");
  const txn3 = await gasRestrictor.addDapp(walletRegistry.address);
  await txn3.wait();
  console.log("added walletRegistry in gasrestrictor");
  // const txn4 = await gasRestrictor.addDapp(messagingUpgradeable.address);
  // await txn4.wait();
  // console.log("added messagingUpgradeable in gasrestrictor");

  // const addTrustedForwarder1 = await walletRegistry.addOrRemovetrustedForwarder(
  //   trustedForwarder,
  //   true
  // );
  // await addTrustedForwarder1.wait();
  // const addTrustedForwarder2 =
  //   await subscriptionModule.addOrRemovetrustedForwarder(
  //     trustedForwarder,
  //     true
  //   );
  // await addTrustedForwarder2.wait();

  // const addTrustedForwarder3 = await gamification.addOrRemovetrustedForwarder(
  //   trustedForwarder,
  //   true
  // );
  // await addTrustedForwarder3.wait();

  // const addTrustedForwarder4 = await gasRestrictor.addOrRemovetrustedForwarder(
  //   trustedForwarder,
  //   true
  // );
  // await addTrustedForwarder4.wait();

  console.log("succesfully ran script, all contract deployed");
}

async function deploySubscriptionModule() {
  const trustedForwarderSelf = "0x700CCB796874829DfAF93A175de9560f4e7d4E34";
  const SubscriptionModule = await ethers.getContractFactory("SubscriptionModule");

  const subscriptionModule = await upgrades.deployProxy(
    SubscriptionModule,
    [2000, 3600 * 24 * 30, trustedForwarderSelf, "0xA2b785C47a1aF5CCDb66a76a44b0D1816F079253"],
    {
      initializer: "__subscription_init",
    }
  );

  await subscriptionModule.deployed();

  console.log("subscriptionModule deployed to:", subscriptionModule.address);
}

async function deployMessaging() {
  const [deployer] = await ethers.getSigners();
  console.log("deployer", deployer.address);
  // polygon
  // const trustedForwarder = "0xf0511f123164602042ab2bCF02111fA5D3Fe97CD";
  // const trustedForwarderSelf = "0x5D5279793144210fE34b67C2bCd767Ecba24334D";
  // fantom
  const trustedForwarder = "0x64CD353384109423a966dCd3Aa30D884C9b2E057";
  const trustedForwarderSelf = "0x44AC9E2A726449987105b7153072eEAF0B64A556";

  const MessagingUpgradeable = await ethers.getContractFactory(
    "MessagingUpgradeable"
  );

  const dappId =
    "0x5745CDA224D510EF4E4DA873003462AB398939371C1923F78B8B2DA4E0A700F6";
  // polgon
  // const ufarmTokenAddress = "0xA7305Ae84519fF8Be02484CdA45834C4E7D13Dd6";
  // fantom
  const ufarmTokenAddress = "0x40986a85B4cFCDb054A6CBFB1210194fee51af88";
  const spamTokensAdmin = "0x2fe4540239f6b01addf75E15239FBeFA226eB6BE";

  const messagingUpgradeable = await upgrades.deployProxy(
    MessagingUpgradeable,
    [
      dappId,
      "0xd293D5f79A6187FDB5f91b01F55f92ca4Cc9C731",     // subscriptionModule.address,
      "0xb54A55aA2800369f5c7FF3CbbD64388c5A22cFb6",     // gasRestrictor.address,
      ufarmTokenAddress,
      spamTokensAdmin,
      trustedForwarderSelf,
    ],
    {
      initializer: "__Messaging_init",
    }
  );

  await messagingUpgradeable.deployed();

  console.log(
    "MessagingUpgradeable deployed to:",
    messagingUpgradeable.address
  );

  const tx = await messagingUpgradeable.addOrRemovetrustedForwarder(
    trustedForwarder,
    true
  );
  await tx.wait();
  console.log("Bico trusted forwarder added");

  const GasRestrictor = await ethers.getContractFactory("GasRestrictor");
  const gasRestrictor = GasRestrictor.attach("0xb54A55aA2800369f5c7FF3CbbD64388c5A22cFb6");
  const txn4 = await gasRestrictor.addDapp(messagingUpgradeable.address);
  await txn4.wait();
  console.log("added messagingUpgradeable in gasrestrictor");
}

async function deploySingleContract() {
  const UnifarmAccountsUpgradeable = await ethers.getContractFactory(
    "UnifarmAccountsUpgradeable"
  );
  const unifarmAccountsUpgradeable = await UnifarmAccountsUpgradeable.deploy();

  await unifarmAccountsUpgradeable.deployed();

  console.log(
    "unifarmAccountsUpgradeable deployed to:",
    unifarmAccountsUpgradeable.address
  );
}

async function getDappById() {
  const unifarmAccountsAddress = "0x615Ab9cda0C97a5d77634bCe5CbA27cc36039C81";
  const dappId =
    "0x80974a5028c5eea665958c46f9f1735cf229be42cdaea829dbd2587fc4a61a3a";

  const UnifarmAccountsUpgradeable = await ethers.getContractFactory(
    "UnifarmAccountsUpgradeable"
  );
  const contract = await UnifarmAccountsUpgradeable.attach(
    unifarmAccountsAddress
  );
  // const dapp = await contract.dapps(dappId);
  // const verifiedDappsCount = await contract.verifiedDappsCount();
  const dapp2 = await contract.getDapp(dappId);

  // console.log("Dapp: ", dapp, verifiedDappsCount);
  console.log("Dapp2: ", dapp2);
}

async function verifyDapp() {
  const unifarmAccountsAddress = "0xc687Bc92bf5ceDf112f120ec795C5b037558b3e7";
  const dappId =
    "0x0000000000000000000000000000000000000000000000000000000000000000";
  const verificationStatus = true;

  const UnifarmAccountsUpgradeable = await ethers.getContractFactory(
    "UnifarmAccountsUpgradeable"
  );
  const contract = await UnifarmAccountsUpgradeable.attach(
    unifarmAccountsAddress
  );
  const tx = await contract.appVerification(dappId, verificationStatus, false);
  await tx.wait();
  console.log("Dapp verified!");
}

async function createWallet() {
  const [
    _dappsAdmin,
    _appAdmin,
    _subscriber,
    _subscriberSecondary,
    _notificationSender,
  ] = await ethers.getSigners();
  const unifarmAccountsAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
  const dappId =
    "0x0000000000000000000000000000000000000000000000000000000000000000";
  const verificationStatus = true;

  const UnifarmAccountsUpgradeable = await ethers.getContractFactory(
    "UnifarmAccountsUpgradeable"
  );
  const contract = await UnifarmAccountsUpgradeable.attach(
    unifarmAccountsAddress
  );
  const tx = await contract
    .connect(_subscriber)
    .createWallet(_subscriberSecondary.address, "asd", "asd", "", false, constants.AddressZero);
  await tx.wait();
  console.log("Dapp verified!");
}

async function parseTxLog() {
  const UnifarmAccountsUpgradeable = await ethers.getContractFactory(
    "UnifarmAccountsUpgradeable"
  );

  const iface = UnifarmAccountsUpgradeable.interface;
  // const iface = new ethers.utils.Interface([]);
  const data =
    "0x3958a9a86d4dc4fea8cd6a86e38f084e6cc7a4accde97e33f59ca65f2fc523a448782ae6000000000000000000000000900bc7216b7ede964040db0bcf681975aeb2693b00000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e23034636230353430616335396464326335346536613564613233326338343962303266663731343062613633343665326366656261343063323662323161613739613131336634626135366638356466363530306330306561643630336266643663633339393038616238653837633233306137303636356333353532623338323832356164663730343931326436666236643165356236353930633165656663313437636136653030383436326132303638666431363661653461333135323863353232613630366463376335333734633466306266326261343832633730356400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c2353962633636623735306435326365633161323237326663306538356630643830333635663965383533646330373165353164626630373065633464306466326331373936663436646363333532323339366534666530303066363666366130363335623738396262393232643330323763346433373264623535616230666332633366613735396631633333643332316365636563643231373837346365636438663437383738623839336563663034616365613438393366326632346133366600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c26231613935646230656666313639313862373637343430333834626235653663303339353235623438363165366430663566326138323038373562376263643337666665616161623162336363646432373930313935303565613536373639353366336236353332383731656361393338663434313363623834376563343561643636353530633537313033636330643830616532643265333236633635346338303836383033303330383461626133646531663732303434633333373138613738000000000000000000000000000000000000000000000000000000000000";
  const res = iface.parseTransaction({ data });
  console.log("res: ", res);
}

async function upgradeWalletRegistry() {
  const walletRegistryContractAddress =
    "0xaCbB8F1917E5746C1a02F64FC753D25a781eAE12";
  const WalletRegistry = await ethers.getContractFactory(
    "WalletRegistry"
  );
  const walletRegistry = await upgrades.upgradeProxy(
    walletRegistryContractAddress,
    WalletRegistry
  );
  console.log("WalletRegistry upgraded");
}

async function upgradeSubscriptionModule() {
  const subscriptionModuleContractAddress =
    "0xcd4De28E94F4ac6546dfE51b9a1A4ca280806a7d";
  const SubscriptionModule = await ethers.getContractFactory(
    "SubscriptionModule"
  );
  const subscriptionModule = await upgrades.upgradeProxy(
    subscriptionModuleContractAddress,
    SubscriptionModule
  );
  console.log("SubscriptionModule upgraded");
}

async function upgradeGamification() {
  const gamificationContractAddress =
    "0x06075a3b002B4bdCBc066358EF641745B63d265b";
  const Gamification = await ethers.getContractFactory(
    "Gamification"
  );
  const gamification = await upgrades.upgradeProxy(
    gamificationContractAddress,
    Gamification
  );
  console.log("Gamification upgraded");
}

async function deployDappsDns() {
  try {
    // 5ire
    const trustedForwarderSelf = "0x77848747CF7aE80310b081CB4926e52270E0baA5", 
          subsModule = "0x47d838B117A515BdFe91573E91CF071109D07980",
          gasRestrictor = "0xA54b811C16cE6cd396ac0374508d265bFA55CCA3";
    const DappsDns = await ethers.getContractFactory("DappsDns");

    const dappsDns = await upgrades.deployProxy(
      DappsDns,
      [subsModule, gasRestrictor, trustedForwarderSelf],
      {
        initializer: "__DappsDns_init",
      }
    );
    await dappsDns.deployed();
    console.log("DappsDns deployed on: ", dappsDns.address);

    // const txn55 = await dappsDns.updateGasRestrictor(gasRestrictor);
    // await txn55.wait();

  } catch (error) {
    console.log("Error in deployDappsDns: ", error);
  }
}

async function upgradeDappsDns() {
  const dappsDnsContractAddress =
    "0x271437C9B2069F13Cc197B9e12A02ED276ae3A85";
  const DappsDns = await ethers.getContractFactory(
    "DappsDns"
  );
  const dappsDns = await upgrades.upgradeProxy(
    dappsDnsContractAddress,
    DappsDns
  );
  console.log("DappsDns upgraded");
}

async function addTld() {
  // const [
  //   _dappsAdmin
  // ] = await ethers.getSigners();
  const dappsDnsAddress = "0x271437C9B2069F13Cc197B9e12A02ED276ae3A85";
  const dappId =
    "0xb694b54ffd2133dfa2d52a97737303d8d318f7dced12f1a4885c803d3b02a2ec";
  const tldName = ".5ire";
  const onSale = true;

  const DappsDns = await ethers.getContractFactory(
    "DappsDns"
  );
  const contract = await DappsDns.attach(
    dappsDnsAddress
  );
  const tx = await contract.addTld(dappId, tldName, onSale);
  await tx.wait();
  console.log(tldName, " tld added!");
}

async function getTld() {
  const dappsDnsAddress = "0xAE755D7B19f1bfe61948f0C0937d846F204ec674";
  const dappId =
    "0xb694b54ffd2133dfa2d52a97737303d8d318f7dced12f1a4885c803d3b02a2ec";

  const DappsDns = await ethers.getContractFactory(
    "DappsDns"
  );
  const contract = await DappsDns.attach(
    dappsDnsAddress
  );
  const res = await contract.tlds(dappId);
  console.log("tld res: ", res);
}

async function claimDomain() {
  try {
    const [
      _dappsAdmin
    ] = await ethers.getSigners();
    const dappsDnsAddress = "0xAE755D7B19f1bfe61948f0C0937d846F204ec674";
    const dappId =
      "0xb694b54ffd2133dfa2d52a97737303d8d318f7dced12f1a4885c803d3b02a2ec";
    const tldName = ".5ire";
    const onSale = true;

    const DappsDns = await ethers.getContractFactory(
      "DappsDns"
    );
    const contract = await DappsDns.attach(
      dappsDnsAddress
    );
    const tx = await contract.claimDomain(_dappsAdmin.address, dappId, "rajat.5ire", false);
    await tx.wait();
    console.log(tldName, " tld added!");
  } catch (error) {
    console.log("Error in claimDomain: ", error);
  }
}

async function getNoOfWallets() {
  const walletRegistryAddress = "0xE667de8E2cd583D3fE8AC107Ba4547EaaF0a1561";

  const WalletRegistry = await ethers.getContractFactory(
    "WalletRegistry"
  );
  const contract = await WalletRegistry.attach(
    walletRegistryAddress
  );
  const res = await contract.noOfWallets();
  console.log("reg contracts: ", res);
}

async function getRegDappContract() {
  const subscriptionModuleAddress = "0x47d838B117A515BdFe91573E91CF071109D07980";

  const SubscriptionModule = await ethers.getContractFactory(
    "SubscriptionModule"
  );
  const contract = await SubscriptionModule.attach(
    subscriptionModuleAddress
  );
  const res = await contract.dappsCount();
  console.log("reg contracts: ", res);
}

async function addDapp() {
  const Gamification = await ethers.getContractFactory("Gamification");
const gamif =  Gamification.attach("0x612Aa0749f3e3670710b3bAcaa988aF1a0D3176a");

let addDapp1 = await gamif.addDapp("0xE667de8E2cd583D3fE8AC107Ba4547EaaF0a1561");
await addDapp1.wait();
console.log("done", await gamif.isDappsContract("0x47d838B117A515BdFe91573E91CF071109D07980"));

}

// mumbai - 0xf46477D1363930B6Ca141fa251C9B31d04CdC7Fe
// polygon - 0x5851333A71b7EC246BB96Cd42797B9D9b20Abd40
async function deployDappsDnsNew() {
  try {
    // 5ire
    const trustedForwarderSelf = "0xc0e2F1aB33b19DFb5FAea966E1bDC4E955858ecd", 
          subsModule = "0xcd4De28E94F4ac6546dfE51b9a1A4ca280806a7d",
          gasRestrictor = "0x77a6356c8A651fD838C4941D13A99aa7A6419Ae9",
          annualPrice = utils.parseEther("0.001"),
          lifetimePrice = utils.parseEther("0.0025");
    const DappsDnsNew = await ethers.getContractFactory("DappsDnsNew");

    const dappsDnsNew = await upgrades.deployProxy(
      DappsDnsNew,
      [subsModule, gasRestrictor, trustedForwarderSelf, annualPrice, lifetimePrice],
      {
        initializer: "__DappsDns_init",
      }
    );
    await dappsDnsNew.deployed();
    console.log("DappsDns deployed on: ", dappsDnsNew.address);

    // const txn55 = await dappsDns.updateGasRestrictor(gasRestrictor);
    // await txn55.wait();

  } catch (error) {
    console.log("Error in deployDappsDnsNew: ", error);
  }
}

async function registerDomain() {
  try {
    const [
      _dappsAdmin
    ] = await ethers.getSigners();
    const dappsDnsAddress = "0xc34782e682477E1562312eDAAEeD341497119F6c";
    const user = "0x900bC7216b7eDE964040dB0BCf681975aeB2693b",
          tld = "matic",
          name = "rajat",
          isForLifetime = false,
          referrer = "",
          isOauthUser = false;

    const DappsDnsNew = await ethers.getContractFactory(
      "DappsDnsNewEnumerable"
    );
    const contract = await DappsDnsNew.attach(
      dappsDnsAddress
    );
    const tx = await contract.registerDomain(user, tld, name, isForLifetime, referrer, isOauthUser, {
      value: utils.parseEther("0.001")
    });
    await tx.wait();
    console.log(name + "." + tld, " domain registered!");
  } catch (error) {
    console.log("Error in registerDomain: ", error);
  }
}

async function setRecord() {
  try {
    const [
      _dappsAdmin
    ] = await ethers.getSigners();
    const dappsDnsAddress = "0xAE755D7B19f1bfe61948f0C0937d846F204ec674";
    // const dappId = "0xb694b54ffd2133dfa2d52a97737303d8d318f7dced12f1a4885c803d3b02a2ec";

    let user = _dappsAdmin.address,
      name = "rajat.5ire",      // web3 domain
      recordIndex = 0,       // 0 if new record is to be added, otherwise the index to be updated
      recordType = 1,
      domain = "www.rajat.com",
      location = "127.0.0.1",
      priority = 0,
      isOauthUser = false;

    const DappsDns = await ethers.getContractFactory(
      "DappsDns"
    );
    const contract = await DappsDns.attach(
      dappsDnsAddress
    );
    const tx = await contract.setRecord(user, name, recordIndex, recordType, domain, location, priority, isOauthUser);
    await tx.wait();
    console.log("record added");
  } catch (error) {
    console.log("Error in setRecord: ", error);
  }
}

async function getDomain() {
  try {
    const [
      _dappsAdmin
    ] = await ethers.getSigners();
    const dappsDnsAddress = "0x271437C9B2069F13Cc197B9e12A02ED276ae3A85";

    const DappsDns = await ethers.getContractFactory(
      "DappsDns"
    );
    const contract = await DappsDns.attach(
      dappsDnsAddress
    );
    const tx = await contract.domains("rajat.5ire");
    console.log("domain: ", tx);
  } catch (error) {
    console.log("Error in setRecord: ", error);
  }
}

async function upgradeDappsDnsNew() {
  const dappsDnsNewContractAddress =
    "0xEfd9CF617C46c4f538e49da5ddF29ACaEE50A2a8";
  const DappsDnsNew = await ethers.getContractFactory(
    "DappsDnsNew"
  );
  const dappsDns = await upgrades.upgradeProxy(
    dappsDnsNewContractAddress,
    DappsDnsNew
  );
  console.log("DappsDnsNew upgraded");
}

deployAll().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
