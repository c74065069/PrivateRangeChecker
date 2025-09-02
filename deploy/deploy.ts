// deploy/001_deploy_private_range_checker.ts
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Дефолты на случай отсутствия переменных окружения
const DEFAULTS: Record<string, { lower: number; upper: number }> = {
  sepolia:  { lower: 0, upper: 1_000_000 }, // [0, 1e6)
  hardhat:  { lower: 0, upper: 100 },
  localhost:{ lower: 0, upper: 100 },
};

function parseU32Maybe(v?: string): number | undefined {
  if (v === undefined) return undefined;
  const n = Number(v);
  if (!Number.isInteger(n) || n < 0 || n > 0xffffffff) return undefined;
  return n;
}

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts, network } = hre;
  const { deploy, log, read } = deployments;
  const { deployer } = await getNamedAccounts();

  log("----------------------------------------------------");
  log(`Network: ${network.name}`);
  log(`Deployer: ${deployer}`);

  // Берём из .env, если есть; иначе — дефолты по сети
  const envLower = parseU32Maybe(process.env.RANGE_LOWER);
  const envUpper = parseU32Maybe(process.env.RANGE_UPPER);
  const defaults = DEFAULTS[network.name] ?? { lower: 0, upper: 1_000_000 };

  const lower = envLower ?? defaults.lower;
  const upper = envUpper ?? defaults.upper;

  if (!(Number.isInteger(lower) && Number.isInteger(upper) && lower >= 0 && upper <= 0xffffffff && lower < upper)) {
    throw new Error(`Bad bounds computed: lower=${lower}, upper=${upper}`);
  }

  if (envLower === undefined || envUpper === undefined) {
    log(`(info) .env not set → using defaults for ${network.name}: [${lower}, ${upper})`);
  } else {
    log(`Using .env bounds: [${lower}, ${upper})`);
  }

  const res = await deploy("PrivateRangeChecker", {
    from: deployer,
    args: [lower, upper], // ✅ передаём 2 аргумента в конструктор
    log: true,
  });

  log(`✅ PrivateRangeChecker deployed at: ${res.address}`);

  const lb: bigint = await read("PrivateRangeChecker", "lowerBound");
  const ub: bigint = await read("PrivateRangeChecker", "upperBound");
  log(`Bounds on-chain: [${lb}, ${ub})`);

  const version: string = await read("PrivateRangeChecker", "version");
  log(`version(): ${version}`);

  log("----------------------------------------------------");
};

export default func;
func.id = "deploy_PrivateRangeChecker";
func.tags = ["PrivateRangeChecker"];
