import json

with open('data.json', 'r') as f:
    data = json.load(f)
    print(data)

# 写一个冒泡排序的函数
def bubble_sort(data):
    """
    Sorts the given list using the bubble sort algorithm.

    Parameters:
    data (list): The list to be sorted.

    Returns:
    list: The sorted list.
    """
    for i in range(len(data) - 1):
        for j in range(len(data) - 1 - i):
            if data[j] > data[j + 1]:
                data[j], data[j + 1] = data[j + 1], data[j]
    return data

# 写一个快速排序
def quick_sort(data):
    """
    Sorts the given list using the quick sort algorithm.

    Parameters:
    data (list): The list to be sorted.

    Returns:
    list: The sorted list.
    """
    if len(data) <= 1:
        return data
    if 
    
    
    
    pivot = data[len(data) // 2]
    left = [x for x in data if x < pivot]
    middle = [x for x in data if x == pivot]
    right = [x for x in data if x > pivot]
    return quick_sort(left) + middle + quick_sort(right)


  
    