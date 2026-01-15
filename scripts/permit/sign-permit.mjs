import { ethers } from "ethers";

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? null : process.argv[i + 1];
}

function need(name, v) {
  if (!v) throw new Error(`Missing --${name}`);
  return v;
}

async function main() {
  const rpc = arg("rpc") || process.env.RPC_URL;
  need("rpc", rpc);

  const pk = arg("pk") || process.env.PRIVATE_KEY;
  need("pk", pk);

  const tokenAddr = need("token", arg("token"));
  const spender = need("spender", arg("spender"));
  const valueStr = need("value", arg("value"));
  const deadlineStr = need("deadline", arg("deadline"));

  const provider = new ethers.JsonRpcProvider(rpc);
  const wallet = new ethers.Wallet(pk, provider);
  const owner = await wallet.getAddress();

  const token = new ethers.Contract(
    tokenAddr,
    [
      "function name() view returns (string)",
      "function nonces(address) view returns (uint256)"
    ],
    provider
  );

  const name = await token.name();
  const nonce = await token.nonces(owner);
  const { chainId } = await provider.getNetwork();

  const domain = {
    name,
    version: "1",
    chainId: Number(chainId),
    verifyingContract: tokenAddr
  };

  const types = {
    Permit: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
      { name: "value", type: "uint256" },
      { name: "nonce", type: "uint256" },
      { name: "deadline", type: "uint256" }
    ]
  };

  const message = {
    owner,
    spender,
    value: BigInt(valueStr),
    nonce: BigInt(nonce),
    deadline: BigInt(deadlineStr)
  };

  const signature = await wallet.signTypedData(domain, types, message);
  const sig = ethers.Signature.from(signature);
  const digest = ethers.TypedDataEncoder.hash(domain, types, message);
  const recovered = ethers.verifyTypedData(domain, types, message, signature);

  console.log({ owner, recovered, digest });
  console.log("signature:", signature);
  console.log("v:", sig.v);
  console.log("r:", sig.r);
  console.log("s:", sig.s);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
