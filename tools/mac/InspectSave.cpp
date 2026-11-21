#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
#include "Encryption/Encryption.h"
#include "Trainer/Trainer9LZA.h"
#include "Pokemon/Pokemon.h"
int main(int argumentCount, char **arguments)
{
    if (argumentCount != 2 && argumentCount != 3 && argumentCount != 5) return 1;
    std::ifstream inputFile(arguments[1], std::ios::binary);
    std::vector<uint8_t> fileBytes{std::istreambuf_iterator<char>(inputFile), std::istreambuf_iterator<char>()};
    auto blocks = Encryption::decrypt(fileBytes.data(), fileBytes.size());
    if (argumentCount == 3)
    {
        for (const auto &block : blocks)
        {
            if (block.key != Trainer::ITEM9_LZA) continue;
            std::ofstream outputFile(arguments[2], std::ios::binary);
            outputFile.write(reinterpret_cast<const char *>(block.data.data()), block.data.size());
        }
        return 0;
    }
    if (argumentCount == 5)
    {
        std::ifstream donorFile(arguments[2], std::ios::binary);
        std::vector<uint8_t> donorBytes{std::istreambuf_iterator<char>(donorFile), std::istreambuf_iterator<char>()};
        auto donorBlocks = Encryption::decrypt(donorBytes.data(), donorBytes.size());
        const uint32_t blockId = strtoul(arguments[4], nullptr, 16);
        bool replaced = false;
        for (auto &block : blocks)
        {
            if (block.key != blockId) continue;
            for (const auto &donorBlock : donorBlocks)
            {
                if (donorBlock.key == blockId)
                {
                    block = donorBlock;
                    replaced = true;
                    break;
                }
            }
        }
        if (!replaced) return 2;
        const auto writtenBytes = Encryption::encrypt(blocks);
        std::ofstream outputFile(arguments[3], std::ios::binary);
        outputFile.write(reinterpret_cast<const char *>(writtenBytes.data()), writtenBytes.size());
        return outputFile.good() ? 0 : 3;
    }
    Trainer::Trainer9LZA trainer(blocks);
    std::cout << "valid=" << trainer.isValid() << " name=" << trainer.trainerName << " money=" << trainer.money << " revision=" << trainer.saveRevisionString << "\n";
    for (size_t pouchIndex = 0; pouchIndex < trainer.items.size(); ++pouchIndex)
    {
        for (const auto &item : trainer.items[pouchIndex])
        {
            if (item.itemId >= 2400 && item.count) std::cout << "pouch " << pouchIndex << " item " << item.itemId << " count " << item.count << "\n";
        }
    }
    auto describe = [](const ::Pokemon::Pokemon *pokemon)
    {
        if (!pokemon || !pokemon->speciesID()) return;
        std::cout << pokemon->speciesID() << " " << pokemon->species() << " form=" << static_cast<int>(pokemon->form()) << " level=" << static_cast<int>(pokemon->level()) << " item=" << pokemon->heldItem() << " egg=" << pokemon->isEgg() << " moves=";
        for (int moveIndex = 0; moveIndex < 4; ++moveIndex) std::cout << pokemon->move(moveIndex) << ",";
        std::cout << "\n";
    };
    for (size_t partyIndex = 0; partyIndex < trainer.party.size(); ++partyIndex)
    {
        std::cout << "party " << partyIndex << " ";
        describe(trainer.party[partyIndex].get());
    }
    for (size_t boxIndex = 0; boxIndex < trainer.boxes.size(); ++boxIndex)
    {
        for (size_t slotIndex = 0; slotIndex < trainer.boxes[boxIndex].size(); ++slotIndex)
        {
            const auto &pokemon = trainer.boxes[boxIndex][slotIndex];
            if (!pokemon || !pokemon->speciesID()) continue;
            std::cout << "box " << boxIndex << " slot " << slotIndex << " ";
            describe(pokemon.get());
        }
    }
}
