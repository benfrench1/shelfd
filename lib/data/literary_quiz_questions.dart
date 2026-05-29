import '../models/literary_quiz_question.dart';

final List<LiteraryQuizQuestion> literaryQuizQuestions = [
  // Batch 1
  _q(
    'Winston Smith is the protagonist of which George Orwell novel?',
    '1984',
    'Animal Farm',
    'Brave New World',
    'Fahrenheit 451',
    0,
  ),
  _q(
    'What magazine does Stieg Larsson’s character Mikael Blomkvist work at, and part own in ‘The Girl With The Dragon Tattoo’ and its subsequent novels?',
    'Time',
    'Vogue',
    'Millennium',
    'The Guardian',
    2,
  ),
  _q(
    'In which mythical land are the ‘Lord of the Rings’ books set?',
    'Hogwarts',
    'Narnia',
    'Westeros',
    'Middle-earth',
    3,
  ),
  _q(
    'In ‘Pride and Prejudice’, what is the full name of Elizabeth Bennet’s love interest?',
    'Mr. Darcy',
    'Mr. Bingley',
    'Mr. Collins',
    'Mr. Wickham',
    0,
  ),
  _q(
    'What is the name of Harper Lee’s debut novel?',
    'Go Set a Watchman',
    'To Kill a Mockingbird',
    'The Catcher in the Rye',
    'The Great Gatsby',
    1,
  ),

  // Batch 2
  _q('Natasha Rostov is the heroine of which classic Russian novel?', 'Crime and Punishment', 'Anna Karenina', 'War and Peace', 'The Brothers Karamazov', 2),
  _q('What do George Eliot, George Sand and Acton Bell all have in common?', 'They are all male authors', 'They are all female authors using male pseudonyms', 'They are all French authors', 'They are all British authors', 1),
  _q('Which female classic author wrote Mrs Dalloway in 1925?', 'Virginia Woolf', 'Jane Austen', 'Charlotte Brontë', 'Emily Brontë', 0),
  _q('Which 1920 book famously features the line, “Love loves to love love”?', 'Ulysses', 'The Great Gatsby', 'This Side of Paradise', 'Women in Love', 0),
  _q('Who wrote Jane Eyre?', 'Jane Austen', 'Emily Brontë', 'Agatha Christie', 'Charlotte Brontë', 3),

  // Batch 3
  _q('Anastacia Steele is the main protagonist in which series of books?', 'Twilight', 'Fifty Shades', 'The Hunger Games', 'Divergent', 1),
  _q('Who wrote The Iliad?', 'Homer', 'Virgil', 'Sophocles', 'Euripides', 0),
  _q('Which Charles Dickens novel begins with the line: “It was the best of times, it was the worst of times”?', 'Great Expectations', 'A Tale of Two Cities', 'Oliver Twist', 'David Copperfield', 1),
  _q('Who is the narrator of Moby-Dick?', 'Starbuck', 'Ahab', 'Queequeg', 'Ishmael', 3),
  _q('Which novel features the character Heathcliff?', 'Great Expectations', 'Jane Eyre', 'Pride and Prejudice', 'Wuthering Heights', 3),

  // Batch 4
  _q('Who wrote the Divine Comedy?', 'Leonardo da Vinci', 'Dante Alighieri', 'John Milton', 'Homer', 1),
  _q('What is the name of the ship in Treasure Island?', 'Titanic', 'Black Pearl', 'Flying Dutchman', 'Hispaniola', 3),
  _q('Who wrote The Canterbury Tales?', 'Geoffrey Chaucer', 'John Milton', 'William Shakespeare', 'Dante Alighieri', 0),
  _q('In which play does the line “To be, or not to be” appear?', 'Othello', 'Macbeth', 'Hamlet', 'King Lear', 2),
  _q('Who wrote The Count of Monte Cristo?', 'Alexandre Dumas', 'Victor Hugo', 'Jules Verne', 'Honoré de Balzac', 0),

  // Batch 5
  _q('Who is the author of The Old Man and the Sea?', 'John Steinbeck', 'F. Scott Fitzgerald', 'Ernest Hemingway', 'William Faulkner', 2),
  _q('Who is the author of Dracula?', 'HP Lovecraft', 'Mary Shelley', 'Robert Louis Stevenson', 'Bram Stoker', 3),
  _q('Who is the author of The Great Gatsby?', 'F. Scott Fitzgerald', 'Ernest Hemingway', 'John Steinbeck', 'William Faulkner', 0),
  _q('Who is the author of The Godfather?', 'Francis Ford Coppola', 'Mario Puzo', 'Stephen King', 'John Grisham', 1),
  _q('Who is the author of Lord of the Flies?', 'Aldous Huxley', 'George Orwell', 'William Golding', 'Ray Bradbury', 2),

  // Batch 6
  _q('Who is the author of A Brave New World?', 'George Orwell', 'Aldous Huxley', 'William Golding', 'Ray Bradbury', 1),
  _q('Who is the author of A Prayer for Owen Meany?', 'John Irving', 'Stephen King', 'Ernest Hemingway', 'F. Scott Fitzgerald', 0),
  _q('Who is the author of Pride and Prejudice?', 'Mary Shelley', 'Charlotte Brontë', 'Emily Brontë', 'Jane Austen', 3),
  _q('Who is the author of Moby-Dick?', 'Herman Melville', 'Nathaniel Hawthorne', 'Edgar Allan Poe', 'Mark Twain', 0),
  _q('Who is the author of War and Peace?', 'Anton Chekhov', 'Fyodor Dostoevsky', 'Leo Tolstoy', 'Ivan Turgenev', 2),

  // Batch 7
  _q('Which book features the phrase “So it goes”?', 'Catch-22', 'Slaughterhouse-Five', '1984', 'Brave New World', 1),
  _q('Lisbeth Salander first appears in which book?', 'The Girl on the Train', 'The Hobbit', 'The Girl with the Dragon Tattoo', 'The Hunger Games', 2),
  _q('Who wrote The Picture of Dorian Gray?', 'HG Wells', 'Charles Dickens', 'Thomas Hardy', 'Oscar Wilde', 3),
  _q('Who is the creator of the fictional character Sherlock Holmes?', 'Arthur Conan Doyle', 'Agatha Christie', 'Edgar Allan Poe', 'Wilkie Collins', 0),
  _q('In which country is the Kite Runner set?', 'Iran', 'Pakistan', 'India', 'Afghanistan', 3),

  // Batch 8
  _q('The Girl with the Dragon Tattoo was originally published in which language?', 'English', 'Swedish', 'German', 'French', 1),
  _q('What kind of animal is Pi trapped on a lifeboat with throughout most of Life of Pi?', 'Snake', 'Lion', 'Tiger', 'Monkey', 2),
  _q('Who is the author of Silence of the Lambs?', 'Agatha Christie', 'Stephen King', 'John Grisham', 'Thomas Harris', 3),
  _q('Who is the author of The Time Traveler’s Wife?', 'Audrey Niffenegger', 'Stephenie Meyer', 'J.K. Rowling', 'Suzanne Collins', 0),
  _q('Who is the author of The Sun also Rises?', 'Ernest Hemingway', 'F. Scott Fitzgerald', 'John Steinbeck', 'William Faulkner', 0),

  // Batch 9
  _q('Who famously played Don Vito Corleone in the film The Godfather?', 'James Cann', 'Al Pacino', 'Robert De Niro', 'Marlon Brando', 3),
  _q('Who played Harry Potter in the film series?', 'Daniel Radcliffe', 'Rupert Grint', 'Emma Watson', 'Tom Felton', 0),
  _q('Which one of these actors did NOT portray Sherlock Holmes?', 'Benedict Cumberbatch', 'Robert Downey Jr.', 'Johnny Depp', 'Basil Rathbone', 2),
  _q('Who played Frodo Baggins in the Lord of the Rings film series?', 'Elijah Wood', 'Ian McKellen', 'Viggo Mortensen', 'Orlando Bloom', 0),
  _q('The Shawshank Redemption is based on a novella by which author?', 'Clive Cussler', 'John Grisham', 'Stephen King', 'Ernest Hemingway', 2),

  // Batch 10
  _q('Which one of these is NOT a Dan Brown book?', 'The Da Vinci Code', 'Demons and Hell', 'Inferno', 'The Lost Symbol', 1),
  _q('Which one of these is NOT a Stephen King book?', 'The Shining', 'It', 'Villette', 'Carrie', 2),
  _q('Which one of these is NOT a Mario Puzo book?', 'The Godfather', 'The Sicilian', 'Omertà', 'Silence of the Lambs', 3),
  _q('Which one of these is NOT a Yuval Noah Harari book?', 'The Silk Roads', 'Homo Deus', '21 Lessons for the 21st Century', 'Sapiens', 0),
  _q('Which one of these is NOT a George Orwell book?', '1984', 'Animal Farm', 'Brave New World', 'Homage to Catalonia', 2),
];

LiteraryQuizQuestion _q(
  String question,
  String optionA,
  String optionB,
  String optionC,
  String optionD,
  int correctIndex,
) {
  return LiteraryQuizQuestion(
    question: question,
    options: [optionA, optionB, optionC, optionD],
    correctIndex: correctIndex,
  );
}
