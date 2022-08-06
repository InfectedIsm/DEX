const Migrations = artifacts.require("Dex");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};
