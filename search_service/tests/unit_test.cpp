//
// Created by Polad Magerramli on 01.08.25.
//
#include <iostream>
#include <gtest/gtest.h>
#include "InvertedIndex.h"
TEST(AddEntryTest, SameWord){
    InvertedIndex idx;
    std::string word = "hello";
    idx.addEntry(word, {"first_example.txt", 5});
    idx.addEntry(word, {"second_example.txt", 2});
    auto frequencies = idx.getEntries("hello");
    auto res1 = frequencies.contains({"first_example.txt", 5});
    auto res2 = frequencies.contains({"second_example.txt", 2});
    auto res3 = frequencies.contains({"unknown.txt", 2});
    EXPECT_TRUE(res1);
    EXPECT_TRUE(res2);
    EXPECT_FALSE(res3);
}

TEST(AddEntryTest, SameEntries){
    InvertedIndex idx;
    std::string word = "hello";
    idx.addEntry(word, {"first_example.txt", 5});
    idx.addEntry(word, {"first_example.txt", 2});
    auto frequencies = idx.getEntries("hello");
    EXPECT_EQ(frequencies.begin()->filename, "first_example.txt");
    EXPECT_EQ(frequencies.begin()->frequency, 7);
}


int main(int argc, char **argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}