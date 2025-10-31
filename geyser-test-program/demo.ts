#!/usr/bin/env ts-node

import * as anchor from "@coral-xyz/anchor";
import { PublicKey, Connection, Keypair, LAMPORTS_PER_SOL } from "@solana/web3.js";
import * as fs from "fs";

// Configuration
const PROGRAM_ID = new PublicKey("3hschqcggfCGdwA4iHzWa747To1DppsoX5BfKr4DgN6s");
const RPC_URL = "http://localhost:8899";

// Simple program interaction without full Anchor setup
async function demonstrateGeyserPlugin() {
    console.log("=".repeat(50));
    console.log("Geyser Kafka Plugin Demonstration");
    console.log("=".repeat(50));
    
    // Connect to local validator
    const connection = new Connection(RPC_URL, "confirmed");
    
    console.log("\nConnecting to local validator...");
    const version = await connection.getVersion();
    console.log(`✓ Connected to Solana ${version["solana-core"]}`);
    
    // Load wallet
    const walletPath = `${process.env.HOME}/.config/solana/id.json`;
    if (!fs.existsSync(walletPath)) {
        console.error("❌ Wallet not found at:", walletPath);
        console.error("Create one with: solana-keygen new");
        process.exit(1);
    }
    
    const walletKeypair = Keypair.fromSecretKey(
        new Uint8Array(JSON.parse(fs.readFileSync(walletPath, "utf-8")))
    );
    
    console.log("\n📝 Wallet:", walletKeypair.publicKey.toBase58());
    
    // Check balance
    const balance = await connection.getBalance(walletKeypair.publicKey);
    console.log("💰 Balance:", balance / LAMPORTS_PER_SOL, "SOL");
    
    if (balance < 1 * LAMPORTS_PER_SOL) {
        console.log("\n💸 Requesting airdrop...");
        const airdropSig = await connection.requestAirdrop(
            walletKeypair.publicKey,
            2 * LAMPORTS_PER_SOL
        );
        await connection.confirmTransaction(airdropSig);
        console.log("✓ Airdrop confirmed");
    }
    
    // Setup Anchor
    const provider = new anchor.AnchorProvider(
        connection,
        new anchor.Wallet(walletKeypair),
        { commitment: "confirmed" }
    );
    anchor.setProvider(provider);
    
    // Load IDL
    const idlPath = "./target/idl/geyser_test_program.json";
    if (!fs.existsSync(idlPath)) {
        console.error("❌ IDL not found at:", idlPath);
        console.error("Run: ./deploy.sh");
        process.exit(1);
    }
    
    const idl = JSON.parse(fs.readFileSync(idlPath, "utf-8"));
    const program = new anchor.Program(idl, PROGRAM_ID, provider);
    
    console.log("\n📋 Program ID:", program.programId.toBase58());
    
    // Generate a counter account
    const counter = Keypair.generate();
    console.log("\n🔑 Counter Account:", counter.publicKey.toBase58());
    
    // Test 1: Initialize
    console.log("\n" + "=".repeat(50));
    console.log("Test 1: Initialize Counter");
    console.log("=".repeat(50));
    
    try {
        const tx1 = await program.methods
            .initialize()
            .accounts({
                counter: counter.publicKey,
                user: walletKeypair.publicKey,
                systemProgram: anchor.web3.SystemProgram.programId,
            })
            .signers([counter])
            .rpc();
        
        console.log("✓ Transaction:", tx1);
        await connection.confirmTransaction(tx1);
        
        const counterAccount = await program.account.counter.fetch(counter.publicKey);
        console.log("✓ Counter value:", counterAccount.count.toString());
        console.log("✓ Authority:", counterAccount.authority.toBase58());
        
        console.log("\n📊 Expected Kafka Events:");
        console.log("  - chain_accounts: Counter account created");
        console.log("  - chain_txs: Initialize transaction");
        console.log("  - chain_blocks_metadata: Block with this transaction");
        
    } catch (error) {
        console.error("❌ Initialize failed:", error);
        process.exit(1);
    }
    
    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test 2: Increment
    console.log("\n" + "=".repeat(50));
    console.log("Test 2: Increment Counter (with program logs)");
    console.log("=".repeat(50));
    
    try {
        const tx2 = await program.methods
            .increment()
            .accounts({
                counter: counter.publicKey,
            })
            .rpc();
        
        console.log("✓ Transaction:", tx2);
        await connection.confirmTransaction(tx2);
        
        const counterAccount = await program.account.counter.fetch(counter.publicKey);
        console.log("✓ Counter value:", counterAccount.count.toString());
        
        console.log("\n📊 Expected Kafka Events:");
        console.log("  - chain_accounts: Counter account updated");
        console.log("  - chain_txs: Increment transaction");
        console.log("  - chain_program_logs: Program logs from increment (when Stage 4 complete)");
        
    } catch (error) {
        console.error("❌ Increment failed:", error);
    }
    
    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test 3: Complex Operation
    console.log("\n" + "=".repeat(50));
    console.log("Test 3: Complex Operation (multiple logs)");
    console.log("=".repeat(50));
    
    try {
        const amount = new anchor.BN(42);
        const tx3 = await program.methods
            .complexOperation(amount)
            .accounts({
                counter: counter.publicKey,
            })
            .rpc();
        
        console.log("✓ Transaction:", tx3);
        await connection.confirmTransaction(tx3);
        
        const counterAccount = await program.account.counter.fetch(counter.publicKey);
        console.log("✓ Counter value:", counterAccount.count.toString());
        
        console.log("\n📊 Expected Kafka Events:");
        console.log("  - chain_accounts: Counter account updated");
        console.log("  - chain_txs: ComplexOperation transaction");
        console.log("  - chain_program_logs: Multiple program logs (when Stage 4 complete)");
        console.log("  - chain_events: Simulated Anchor events (when Stage 4 complete)");
        
    } catch (error) {
        console.error("❌ Complex operation failed:", error);
    }
    
    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test 4: Transfer SOL
    console.log("\n" + "=".repeat(50));
    console.log("Test 4: Transfer SOL");
    console.log("=".repeat(50));
    
    try {
        const recipient = Keypair.generate();
        const transferAmount = new anchor.BN(1_000_000); // 0.001 SOL
        
        console.log("📤 Transferring to:", recipient.publicKey.toBase58());
        
        const tx4 = await program.methods
            .transferSol(transferAmount)
            .accounts({
                from: walletKeypair.publicKey,
                to: recipient.publicKey,
                systemProgram: anchor.web3.SystemProgram.programId,
            })
            .rpc();
        
        console.log("✓ Transaction:", tx4);
        await connection.confirmTransaction(tx4);
        
        const recipientBalance = await connection.getBalance(recipient.publicKey);
        console.log("✓ Recipient balance:", recipientBalance / LAMPORTS_PER_SOL, "SOL");
        
        console.log("\n📊 Expected Kafka Events:");
        console.log("  - chain_accounts: Recipient account created");
        console.log("  - chain_accounts: Sender account updated");
        console.log("  - chain_txs: Transfer transaction");
        
    } catch (error) {
        console.error("❌ Transfer failed:", error);
    }
    
    // Summary
    console.log("\n" + "=".repeat(50));
    console.log("✓ Demonstration Complete!");
    console.log("=".repeat(50));
    
    console.log("\n📊 To view Kafka messages, use:");
    console.log("  cd /home/ubuntu/ytest");
    console.log("  ./view_kafka.sh chain_accounts");
    console.log("  ./view_kafka.sh chain_txs");
    console.log("  ./view_kafka.sh chain_blocks_metadata");
    
    console.log("\n💡 Current Implementation Status:");
    console.log("  ✓ Stage 1-3 Complete:");
    console.log("    - Block metadata events (chain_blocks_metadata)");
    console.log("    - Transaction events (chain_txs)");
    console.log("    - Account updates (chain_accounts)");
    console.log("  ⏳ Stage 4-8 Pending:");
    console.log("    - Program logs parsing (chain_program_logs)");
    console.log("    - Anchor events extraction (chain_events)");
}

// Run the demonstration
demonstrateGeyserPlugin()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error("\n❌ Error:", error);
        process.exit(1);
    });
