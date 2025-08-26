#include <iostream>
#include <gtest/gtest.h>
#include "InvertedIndex.h"
TEST(AddEntryTest, SameWord){
    InvertedIndex idx;
    std::string word = "hello";
    idx.addEntry(word, {"first_example.txt", {5,6}});
    idx.addEntry(word, {"second_example.txt", {1,2}});
    auto frequencies = idx.getEntries("hello");
    auto res1 = frequencies.contains({"first_example.txt", {5,6}});
    auto res2 = frequencies.contains({"second_example.txt", {1,2}});
    auto res3 = frequencies.contains({"unknown.txt", {3,4}});
    EXPECT_TRUE(res1);
    EXPECT_TRUE(res2);
    EXPECT_FALSE(res3);
}

TEST(AddEntryTest, SameEntries){
    InvertedIndex idx;
    std::string word = "hello";
    idx.addEntry(word, {"first_example.txt", {1,2,3}});
    idx.addEntry(word, {"first_example.txt", {5,9}});
    auto frequencies = idx.getEntries("hello");
    std::vector<int> expected_frequencies = {1, 2, 3, 5, 9};
    EXPECT_EQ(frequencies.begin()->filename, "first_example.txt");
    EXPECT_EQ(frequencies.begin()->frequency,expected_frequencies);
}

void setupIndexForTest(InvertedIndex& index) {
    // Файл 1: "Hello world, this is a test world."
    index.addEntry("hello", {"file1.txt", {0}});
    index.addEntry("world", {"file1.txt", {1, 5}});
    index.addEntry("this", {"file1.txt", {2}});
    index.addEntry("is", {"file1.txt", {3}});
    index.addEntry("a", {"file1.txt", {4}});
    index.addEntry("test", {"file1.txt", {6}});

    // Файл 2: "Hello, another test."
    index.addEntry("hello", {"file2.txt", {0}});
    index.addEntry("another", {"file2.txt", {1}});
    index.addEntry("test", {"file2.txt", {2}});
    index.addEntry("Please", {"file2.txt", {4}});
    index.addEntry("don", {"file2.txt", {5}});
    index.addEntry("t", {"file2.txt", {6}});
    index.addEntry("spoil", {"file2.txt", {7}});
    index.addEntry("my", {"file2.txt", {8}});
    index.addEntry("day", {"file2.txt", {9}});

    index.addEntry("Please", {"file3.txt", {0}});
    index.addEntry("don", {"file3.txt", {1}});
    index.addEntry("t", {"file3.txt", {2}});
    index.addEntry("spoil", {"file3.txt", {3}});
    index.addEntry("my", {"file3.txt", {4}});
    index.addEntry("day", {"file3.txt", {5}});
    index.addEntry("Please", {"file3.txt", {7}});
    index.addEntry("don", {"file3.txt", {8}});
    index.addEntry("t", {"file3.txt", {9}});
    index.addEntry("spoil", {"file3.txt", {10}});
    index.addEntry("my", {"file3.txt", {11}});
    index.addEntry("day", {"file3.txt", {12}});
}

class InvertedIndexTest : public ::testing::Test {
protected:
    InvertedIndex index;
    void SetUp() override {
        setupIndexForTest(index);
    }
};

TEST_F(InvertedIndexTest, SingleWordQuery) {
    // Тестируем поиск одного слова, которое встречается в нескольких файлах
    auto results = index.searchOneQuery("hello");

    // Ожидаем два результата
    EXPECT_EQ(results.size(), 2);

    std::vector<FileMatch> expected_answer = {{"file1.txt",1.0},{"file2.txt",1.0}};
    EXPECT_EQ(results,expected_answer);
}

TEST_F(InvertedIndexTest, PhraseQuery1) {
    // Тестируем поиск фразы "hello world"
    auto results = index.searchOneQuery("hello world");

    // Фраза встречается только в file1.txt
    EXPECT_EQ(results.size(), 1);
    std::vector<FileMatch> expected_answer = {{"file1.txt",1.0}};
    // Проверяем, что результат — file1.txt с рангом 1.0 (самая высокая частота)
    EXPECT_EQ(results,expected_answer);
}
TEST_F(InvertedIndexTest, PhraseQuery2) {

    auto results = index.searchOneQuery("Please don t spoil my day");

    EXPECT_EQ(results.size(), 2);
    std::vector<FileMatch> expected_answer = {{"file2.txt",0.5},{"file3.txt",1.0}};

    EXPECT_EQ(results,expected_answer);
}

TEST_F(InvertedIndexTest, TwoNonSequentialWordsQuery) {
    // Тестируем поиск двух слов, которые не идут подряд, но находятся в одном файле
    // "this" и "test" находятся в file1.txt, но не идут подряд.
    auto results = index.searchOneQuery("this test");

    // Если ваш алгоритм ищет только точные фразы, то результат должен быть пуст.
    EXPECT_EQ(results.size(), 0);
}

TEST_F(InvertedIndexTest, NoMatchQuery) {
    // Тестируем запрос со словом, которого нет в индексе
    auto results = index.searchOneQuery("nonexistent");

    // Ожидаем пустой вектор
    EXPECT_TRUE(results.empty());
}

TEST_F(InvertedIndexTest, EmptyQuery) {
    // Тестируем пустой запрос
    auto results = index.searchOneQuery("");

    // Ожидаем пустой вектор
    EXPECT_TRUE(results.empty());
}

int main(int argc, char **argv) {
    testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}