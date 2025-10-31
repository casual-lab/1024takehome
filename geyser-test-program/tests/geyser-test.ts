import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
// If the generated types file at ../target/types/geyser_test_program is not present,
// use a loose fallback type to avoid module resolution errors during development.
type GeyserTestProgram = any;
import { expect } from "chai";

describe("geyser-test-program", () => {
  // Configure the client to use the local cluster.
  anchor.setProvider(anchor.AnchorProvider.env());

  const program = anchor.workspace.GeyserTestProgram as Program<GeyserTestProgram>;
  const provider = anchor.getProvider();

  // Generate a new keypair for the counter account
  const counter = anchor.web3.Keypair.generate();

  it("Initialize counter account", async () => {
    console.log("Testing initialize...");
    
    const tx = await program.methods
      .initialize()
      .accounts({
        counter: counter.publicKey,
        user: provider.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .signers([counter])
      .rpc();
    
    console.log("Initialize transaction signature:", tx);

    // Fetch the account and check the value
    const counterAccount = await program.account.counter.fetch(counter.publicKey);
    expect(counterAccount.count.toNumber()).to.equal(0);
    console.log("Counter initialized with value:", counterAccount.count.toNumber());
  });

  it("Increment counter", async () => {
    console.log("Testing increment...");
    
    const tx = await program.methods
      .increment()
      .accounts({
        counter: counter.publicKey,
      })
      .rpc();
    
    console.log("Increment transaction signature:", tx);

    // Fetch and verify
    const counterAccount = await program.account.counter.fetch(counter.publicKey);
    expect(counterAccount.count.toNumber()).to.equal(1);
    console.log("Counter after increment:", counterAccount.count.toNumber());
  });

  it("Complex operation with multiple logs", async () => {
    console.log("Testing complex operation...");
    
    const amount = new anchor.BN(42);
    const tx = await program.methods
      .complexOperation(amount)
      .accounts({
        counter: counter.publicKey,
      })
      .rpc();
    
    console.log("Complex operation transaction signature:", tx);

    // Fetch and verify
    const counterAccount = await program.account.counter.fetch(counter.publicKey);
    expect(counterAccount.count.toNumber()).to.equal(43); // 1 + 42
    console.log("Counter after complex operation:", counterAccount.count.toNumber());
  });

  it("Transfer SOL between accounts", async () => {
    console.log("Testing transfer SOL...");
    
    // Create recipient account
    const recipient = anchor.web3.Keypair.generate();
    
    const amount = new anchor.BN(1_000_000); // 0.001 SOL
    const tx = await program.methods
      .transferSol(amount)
      .accounts({
        from: provider.publicKey,
        to: recipient.publicKey,
        systemProgram: anchor.web3.SystemProgram.programId,
      })
      .rpc();
    
    console.log("Transfer SOL transaction signature:", tx);

    // Check recipient balance
    const recipientBalance = await provider.connection.getBalance(recipient.publicKey);
    expect(recipientBalance).to.equal(1_000_000);
    console.log("Recipient balance:", recipientBalance);
  });

  it("Multiple operations to generate various logs", async () => {
    console.log("Running multiple operations...");
    
    // Increment several times
    for (let i = 0; i < 3; i++) {
      const tx = await program.methods
        .increment()
        .accounts({
          counter: counter.publicKey,
        })
        .rpc();
      console.log(`Increment ${i + 1} tx:`, tx);
      
      // Wait a bit between transactions
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    // Final complex operation
    const tx = await program.methods
      .complexOperation(new anchor.BN(100))
      .accounts({
        counter: counter.publicKey,
      })
      .rpc();
    console.log("Final complex operation tx:", tx);

    const counterAccount = await program.account.counter.fetch(counter.publicKey);
    console.log("Final counter value:", counterAccount.count.toNumber());
    expect(counterAccount.count.toNumber()).to.equal(146); // 43 + 3 + 100
  });
});
